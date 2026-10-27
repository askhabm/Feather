//
//  enum.swift
//  Feather
//
//  Created by samara on 3.05.2025.
//

import Foundation
import Combine
import CoreData
import UIKit.UIImpactFeedbackGenerator
import BackgroundTasks

class Download: Identifiable, @unchecked Sendable {
	@Published var progress: Double = 0.0
	@Published var bytesDownloaded: Int64 = 0
	@Published var totalBytes: Int64 = 0
	@Published var unpackageProgress: Double = 0.0
	
	var overallProgress: Double {
		onlyArchiving
		? unpackageProgress
		: (0.3 * unpackageProgress) + (0.7 * progress)
	}
	
	var task: URLSessionDownloadTask?
	var resumeData: Data?
	
	let id: String
	let url: URL
	let fileName: String
	let onlyArchiving: Bool
	var sourceProvenance: SourceAppProvenance?
	// UUID приложения, которое появилось в библиотеке после импорта (для автоподписи)
	var importedUUID: String?
	
	init(
		id: String,
		url: URL,
		onlyArchiving: Bool = false,
		sourceProvenance: SourceAppProvenance? = nil
	) {
		self.id = id
		self.url = url
		self.onlyArchiving = onlyArchiving
		self.sourceProvenance = sourceProvenance
		self.fileName = url.lastPathComponent
	}
}

class DownloadManager: NSObject, ObservableObject {
	static let shared = DownloadManager()
	
	@Published var downloads: [Download] = []
	
	var manualDownloads: [Download] {
		downloads.filter { isManualDownload($0.id) }
	}
	
	private var _session: URLSession!
	var backgroundCompletionHandler: (() -> Void)?
	
#if !targetEnvironment(macCatalyst)
private func _updateBackgroundAudioState() {
	if !downloads.isEmpty {
		BackgroundAudioManager.shared.start()
	} else {
		BackgroundAudioManager.shared.stop()
	}
}
#endif

	
	override init() {
	super.init()
	let configuration = URLSessionConfiguration.default
	_session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
}



	
	func startDownload(
		from url: URL,
		id: String = UUID().uuidString,
		sourceProvenance: SourceAppProvenance? = nil
	) -> Download {
		let requestHasSourceProvenance = sourceProvenance != nil
		if let existingDownload = downloads.first(where: {
			$0.url == url && ($0.sourceProvenance != nil) == requestHasSourceProvenance
		}) {
			resumeDownload(existingDownload)
			return existingDownload
		}
		
		let download = Download(id: id, url: url, sourceProvenance: sourceProvenance)
		
		let task = _session.downloadTask(with: url)
		download.task = task
		task.resume()
		
		downloads.append(download)
		
	    #if !targetEnvironment(macCatalyst)
        _updateBackgroundAudioState()
        #endif

		
		return download
	}
	
	func startArchive(
		from url: URL,
		id: String = UUID().uuidString
	) -> Download {
		let download = Download(id: id, url: url, onlyArchiving: true)
		downloads.append(download)
		
		#if !targetEnvironment(macCatalyst)
		_updateBackgroundAudioState()
		#endif
		
		return download
	}
	
	func resumeDownload(_ download: Download) {
		if let resumeData = download.resumeData {
			let task = _session.downloadTask(withResumeData: resumeData)
			download.task = task
			task.resume()
			
			#if !targetEnvironment(macCatalyst)
			_updateBackgroundAudioState()
			#endif
		} else if let url = download.task?.originalRequest?.url {
			let task = _session.downloadTask(with: url)
			download.task = task
			task.resume()
			
			#if !targetEnvironment(macCatalyst)
			_updateBackgroundAudioState()
			#endif
		}
	}
	
	func cancelDownload(_ download: Download) {
		download.task?.cancel()
		
		if let index = downloads.firstIndex(where: { $0.id == download.id }) {
			downloads.remove(at: index)
			
			#if !targetEnvironment(macCatalyst)
			_updateBackgroundAudioState()

			if #available(iOS 26.0, *) {
				BackgroundTaskManager.shared.stopTask(for: download.id, success: false)
			}
			#endif
		}
	}
	
	func isManualDownload(_ string: String) -> Bool {
		return string.contains("FeatherManualDownload")
	}
	
	func getDownload(by id: String) -> Download? {
		return downloads.first(where: { $0.id == id })
	}
	
	func getDownloadIndex(by id: String) -> Int? {
		return downloads.firstIndex(where: { $0.id == id })
	}
	
	func getDownloadTask(by task: URLSessionDownloadTask) -> Download? {
		return downloads.first(where: { $0.task == task })
	}
}

extension DownloadManager: URLSessionDownloadDelegate {
	
	func handlePachageFile(url: URL, dl: Download) throws {
		// Скачано из каталога: после импорта сразу подписываем и устанавливаем
		let shouldAutoSign = dl.sourceProvenance != nil
		
		FR.handlePackageFile(url, download: dl) { err in
			if err != nil {
				let generator = UINotificationFeedbackGenerator()
				generator.notificationOccurred(.error)
			}
			
			DispatchQueue.main.async {
				if let index = DownloadManager.shared.getDownloadIndex(by: dl.id) {
					DownloadManager.shared.downloads.remove(at: index)
					
					#if !targetEnvironment(macCatalyst)
					if #available(iOS 26.0, *) {
						BackgroundTaskManager.shared.updateProgress(for: dl.id, progress: 1.0)
					}
					
					self._updateBackgroundAudioState()
					#endif
				}
				
				if err == nil, shouldAutoSign, let uuid = dl.importedUUID {
					AutoSign.signImportedApp(uuid: uuid)
				}
			}
		}
	}
	
	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		guard let download = getDownloadTask(by: downloadTask) else { return }
		
		let tempDirectory = FileManager.default.temporaryDirectory
		let customTempDir = tempDirectory.appendingPathComponent("FeatherDownloads", isDirectory: true)
		
		do {
			try FileManager.default.createDirectoryIfNeeded(at: customTempDir)
			
			// Use the server-suggested filename if available, otherwise fallback
			let suggestedFileName = downloadTask.response?.suggestedFilename ?? download.fileName
			let destinationURL = customTempDir.appendingPathComponent(suggestedFileName)
			
			try FileManager.default.removeFileIfNeeded(at: destinationURL)
			try FileManager.default.moveItem(at: location, to: destinationURL)
			
			try handlePachageFile(url: destinationURL, dl: download)
		} catch {
			print("Error handling downloaded file: \(error.localizedDescription)")
		}
	}
	
	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
		guard let download = getDownloadTask(by: downloadTask) else { return }
		
		DispatchQueue.main.async {
			download.progress = totalBytesExpectedToWrite > 0
			? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
			: 0
			download.bytesDownloaded = totalBytesWritten
			download.totalBytes = totalBytesExpectedToWrite
			
			#if !targetEnvironment(macCatalyst)
			if #available(iOS 26.0, *) {
				BackgroundTaskManager.shared.updateProgress(for: download.id, progress: download.overallProgress)
			}
			#endif
		}
	}
	
	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		guard
			let _ = error,
			let downloadTask = task as? URLSessionDownloadTask,
			let download = getDownloadTask(by: downloadTask)
		else {
			return
		}
		
		DispatchQueue.main.async {
			if let index = self.getDownloadIndex(by: download.id) {
				self.downloads.remove(at: index)
			}
		}
	}
	
	func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
		DispatchQueue.main.async {
			self.backgroundCompletionHandler?()
			self.backgroundCompletionHandler = nil
		}
	}
}

// MARK: - Автоподпись после скачивания из каталога
enum AutoSign {
	private static func importedObjects() -> [NSManagedObject] {
		let context = Storage.shared.context
		// если такой сущности нет в базе, тихо выходим (без вылета)
		guard context.persistentStoreCoordinator?.managedObjectModel.entitiesByName["Imported"] != nil else {
			return []
		}
		let request = NSFetchRequest<NSManagedObject>(entityName: "Imported")
		return (try? context.fetch(request)) ?? []
	}
	
	private static func showError(_ message: String) {
		UIAlertController.showAlertWithOk(title: "Автоподпись", message: message)
	}
	
	// Ждёт, пока приложение появится в базе (до ~10 секунд), и запускает подпись
	static func signImportedApp(uuid: String, attempt: Int = 0) {
		if let object = importedObjects().first(where: { ($0.value(forKey: "uuid") as? String) == uuid }) {
			guard let app = object as? AppInfoPresentable else {
				showError("Приложение найдено, но не удалось подготовить его к подписи.")
				return
			}
			sign(app)
			return
		}
		
		if attempt < 20 {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
				signImportedApp(uuid: uuid, attempt: attempt + 1)
			}
		} else {
			showError("Не удалось найти скачанное приложение в библиотеке.")
		}
	}
	
	// Подписывает приложение выбранным сертификатом и ставит
	private static func sign(_ app: AppInfoPresentable) {
		// сертификат, выбранный в настройках (так же, как на экране подписи)
		let request = NSFetchRequest<CertificatePair>(entityName: "CertificatePair")
		request.sortDescriptors = [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)]
		let certificates = (try? Storage.shared.context.fetch(request)) ?? []
		let selectedIndex = UserDefaults.standard.integer(forKey: "feather.selectedCert")
		let certificate = certificates.indices.contains(selectedIndex) ? certificates[selectedIndex] : certificates.first
		
		var options = OptionsManager.shared.options
		
		// без сертификата и без особого режима подписи оставляем приложение в библиотеке
		guard certificate != nil || options.signingOption != .default else {
			showError("Нет сертификата. Добавьте сертификат в настройках, и приложение подпишется.")
			return
		}
		
		// ppq protection и переименования, как на экране подписи
		if
			options.ppqProtection,
			let identifier = app.identifier,
			let cert = certificate,
			cert.ppQCheck
		{
			options.appIdentifier = "\(identifier).\(options.ppqString)"
		}
		
		if
			let currentBundleId = app.identifier,
			let newBundleId = options.identifiers[currentBundleId]
		{
			options.appIdentifier = newBundleId
		}
		
		if
			let currentName = app.name,
			let newName = options.displayNames[currentName]
		{
			options.appName = newName
		}
		
		let finalOptions = options
		
		FR.signPackageFile(
			app,
			using: finalOptions,
			icon: nil,
			certificate: certificate
		) { error in
			if let error {
				UIAlertController.showAlertWithOk(
					title: "Error",
					message: error.localizedDescription
				)
				return
			}
			
			if finalOptions.post_deleteAppAfterSigned, !app.isSigned {
				Storage.shared.deleteApp(for: app)
			}
			
			if finalOptions.post_installAppAfterSigned {
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
					NotificationCenter.default.post(name: Notification.Name("Feather.installApp"), object: nil)
				}
			}
		}
	}
}
