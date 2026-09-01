//
//  UpdateDownloadView.swift
//  Feather
//
//  Created by askhabm on 2026-09-01
//

import SwiftUI
import NimbleViews

// MARK: - View
struct UpdateDownloadView: View {
	@Environment(\.dismiss) var dismiss
	@State private var _downloadedFile: URL?
	@State private var _isDownloading = false
	@State private var _downloadProgress: Double = 0
	@State private var _errorMessage: String?
	@State private var _showError = false
	@State private var _releases: [GitHubRelease] = []
	@State private var _selectedRelease: GitHubRelease?
	@State private var _isLoadingReleases = false
	
	// GitHub репо askhabm
	private let _owner = "askhabm"
	private let _repo = "Feather"
	private let _fileManager = FileManager.default
	
	var body: some View {
		NBNavigationView(.localized("Download Update")) {
			Form {
				if _isLoadingReleases {
					Section {
						HStack {
							ProgressView()
								.padding(.trailing, 8)
							Text(.localized("Loading releases..."))
						}
					}
				} else if _releases.isEmpty {
					Section {
						Text(.localized("No releases found"))
							.foregroundColor(.secondary)
					}
				} else {
					Section(.localized("Available Versions")) {
						ForEach(_releases, id: \.id) { release in
							Button(action: { _selectedRelease = release }) {
								HStack {
									VStack(alignment: .leading, spacing: 4) {
										Text(release.tagName)
											.font(.headline)
											.foregroundColor(.primary)
										Text(release.publishedAt.formatted(date: .abbreviated, time: .omitted))
											.font(.footnote)
											.foregroundColor(.secondary)
									}
									Spacer()
									if _selectedRelease?.id == release.id {
										Image(systemName: "checkmark.circle.fill")
											.foregroundColor(.accentColor)
									}
								}
							}
						}
					}
				}
				
				if let selected = _selectedRelease {
					Section {
						if _isDownloading {
							HStack {
								ProgressView(value: _downloadProgress)
								Text(verbatim: "\(Int(_downloadProgress * 100))%")
									.font(.footnote)
									.foregroundColor(.secondary)
							}
						} else if _downloadedFile != nil {
							HStack {
								Image(systemName: "checkmark.circle.fill")
									.foregroundColor(.green)
								Text(.localized("Downloaded"))
							}
							Button(role: .destructive, action: _deleteDownloadedFile) {
								Label(.localized("Delete"), systemImage: "trash")
							}
						} else {
							Button(action: _startDownload) {
								Label(.localized("Download"), systemImage: "arrow.down.circle")
									.frame(maxWidth: .infinity)
							}
							.buttonStyle(.bordered)
							.tint(.accentColor)
						}
					}
				}
				
				if _downloadedFile != nil {
					Section {
						NavigationLink(destination: InstallationView()) {
							Label(.localized("Go to Installation"), systemImage: "arrow.forward.circle")
						}
					} footer: {
						Text(.localized("Open the downloaded IPA in Installation view to sign and install it."))
					}
				}
			}
		}
		.alert(.localized("Error"), isPresented: $_showError) {
			Button(.localized("OK"), role: .cancel) { }
		} message: {
			Text(_errorMessage ?? .localized("Unknown error"))
		}
		.onAppear {
			_loadReleases()
		}
	}
	
	// MARK: - Actions
	private func _loadReleases() {
		_isLoadingReleases = true
		
		let urlString = "https://api.github.com/repos/\(_owner)/\(_repo)/releases"
		guard let url = URL(string: urlString) else {
			_errorMessage = .localized("Invalid URL")
			_showError = true
			_isLoadingReleases = false
			return
		}
		
		URLSession.shared.dataTask(with: url) { data, response, error in
			DispatchQueue.main.async {
				_isLoadingReleases = false
				
				if let error = error {
					_errorMessage = error.localizedDescription
					_showError = true
					return
				}
				
				guard let data = data else {
					_errorMessage = .localized("No data received")
					_showError = true
					return
				}
				
				do {
					let releases = try JSONDecoder().decode([GitHubRelease].self, from: data)
					_releases = releases.filter { !$0.isDraft }
					
					if !_releases.isEmpty {
						_selectedRelease = _releases[0]
					}
				} catch {
					_errorMessage = .localized("Failed to parse releases")
					_showError = true
				}
			}
		}.resume()
	}
	
	private func _startDownload() {
		guard let release = _selectedRelease,
			  let ipaAsset = release.assets.first(where: { $0.name.hasSuffix(".ipa") }) else {
			_errorMessage = .localized("No IPA found in this release")
			_showError = true
			return
		}
		
		_isDownloading = true
		_downloadProgress = 0
		
		let delegate = DownloadDelegate { progress in
			DispatchQueue.main.async {
				self._downloadProgress = progress
			}
		}
		
		let session = URLSession(
			configuration: .default,
			delegate: delegate,
			delegateQueue: nil
		)
		
		let task = session.downloadTask(with: ipaAsset.downloadUrl) { [weak self] location, response, error in
			self?._handleDownloadComplete(location: location, error: error)
		}
		
		task.resume()
	}
	
	private func _handleDownloadComplete(location: URL?, error: Error?) {
		DispatchQueue.main.async {
			_isDownloading = false
			
			if let error = error {
				_errorMessage = error.localizedDescription
				_showError = true
				return
			}
			
			guard let location = location else {
				_errorMessage = .localized("Download failed")
				_showError = true
				return
			}
			
			let documentsPath = _fileManager.urls(
				for: .documentDirectory,
				in: .userDomainMask
			)[0]
			let savedURL = documentsPath.appendingPathComponent("Feather-update.ipa")
			
			try? _fileManager.removeItem(at: savedURL)
			
			do {
				try _fileManager.moveItem(at: location, to: savedURL)
				_downloadedFile = savedURL
			} catch {
				_errorMessage = .localized("Failed to save file")
				_showError = true
			}
		}
	}
	
	private func _deleteDownloadedFile() {
		guard let file = _downloadedFile else { return }
		try? _fileManager.removeItem(at: file)
		_downloadedFile = nil
	}
}

// MARK: - Models
struct GitHubRelease: Codable {
	let id: Int
	let tagName: String
	let isDraft: Bool
	let publishedAt: Date
	let assets: [GitHubAsset]
	
	enum CodingKeys: String, CodingKey {
		case id
		case tagName = "tag_name"
		case isDraft = "draft"
		case publishedAt = "published_at"
		case assets
	}
}

struct GitHubAsset: Codable {
	let name: String
	let downloadUrl: URL
	
	enum CodingKeys: String, CodingKey {
		case name
		case downloadUrl = "browser_download_url"
	}
}

// MARK: - Download Delegate
private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
	let progressCallback: (Double) -> Void
	
	init(progressCallback: @escaping (Double) -> Void) {
		self.progressCallback = progressCallback
	}
	
	func urlSession(
		_ session: URLSession,
		downloadTask: URLSessionDownloadTask,
		didFinishDownloadingTo location: URL
	) { }
	
	func urlSession(
		_ session: URLSession,
		downloadTask: URLSessionDownloadTask,
		didWriteData bytesWritten: Int64,
		totalBytesWritten: Int64,
		totalBytesExpectedToWrite: Int64
	) {
		let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
		progressCallback(progress)
	}
}

#Preview {
	UpdateDownloadView()
}
