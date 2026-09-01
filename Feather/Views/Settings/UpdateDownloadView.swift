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
	@State private var _releases: [GitHubRelease] = []
	@State private var _selectedRelease: GitHubRelease?
	@State private var _isLoadingReleases = false
	@State private var _errorMessage: String?
	@State private var _showError = false
	
	// GitHub репо askhabm
	private let _owner = "askhabm"
	private let _repo = "Feather"
	
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
										if let body = release.body, !body.isEmpty {
											Text(body.prefix(50) + "...")
												.font(.footnote)
												.foregroundColor(.secondary)
												.lineLimit(1)
										}
										Text(release.publishedAt.formatted(date: .abbreviated, time: .omitted))
											.font(.caption)
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
						if let ipaAsset = selected.assets.first(where: { $0.name.hasSuffix(".ipa") }) {
							Button(action: {
								_openWebInstall(ipaUrl: ipaAsset.downloadUrl.absoluteString)
							}) {
								Label(.localized("Install via Web"), systemImage: "safari")
									.frame(maxWidth: .infinity)
							}
							.buttonStyle(.bordered)
							.tint(.accentColor)
						} else {
							Text(.localized("No IPA found in this release"))
								.foregroundColor(.secondary)
								.font(.footnote)
						}
					} footer: {
						Text(.localized("Opens in Safari for installation. You can sign and install with your certificate."))
					}
				}
				
				Section {
					Link(destination: URL(string: "https://github.com/\(_owner)/\(_repo)/releases/tag/2.9.0")!) {
						Label(.localized("View on GitHub"), systemImage: "link")
					}
				} footer: {
					Text(.localized("Open full release notes and download options."))
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
	
	private func _openWebInstall(ipaUrl: String) {
		// Генерируем manifest.plist с ссылкой на IPA
		let manifestContent = _generateManifest(ipaUrl: ipaUrl)
		
		// Сохраня��м в Documents
		let documentsPath = FileManager.default.urls(
			for: .documentDirectory,
			in: .userDomainMask
		)[0]
		let manifestURL = documentsPath.appendingPathComponent("manifest.plist")
		
		do {
			try manifestContent.write(to: manifestURL, atomically: true, encoding: .utf8)
			
			// Генерируем ссылку для установки
			let manifestURLEncoded = manifestURL.absoluteString
				.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
			let installURL = "itms-services://?action=download-manifest&url=\(manifestURLEncoded)"
			
			if let url = URL(string: installURL) {
				UIApplication.shared.open(url)
			}
		} catch {
			_errorMessage = .localized("Failed to open installer")
			_showError = true
		}
	}
	
	private func _generateManifest(ipaUrl: String) -> String {
		return """
		<?xml version="1.0" encoding="UTF-8"?>
		<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
		<plist version="1.0">
		<dict>
			<key>items</key>
			<array>
				<dict>
					<key>assets</key>
					<array>
						<dict>
							<key>kind</key>
							<string>software-package</string>
							<key>url</key>
							<string>\(ipaUrl)</string>
						</dict>
					</array>
					<key>metadata</key>
					<dict>
						<key>bundle-identifier</key>
						<string>com.askhabm.feather</string>
						<key>bundle-version</key>
						<string>1.0</string>
						<key>kind</key>
						<string>software</string>
						<key>title</key>
						<string>Feather</string>
					</dict>
				</dict>
			</array>
		</dict>
		</plist>
		"""
	}
}

// MARK: - Models
struct GitHubRelease: Codable {
	let id: Int
	let tagName: String
	let body: String?
	let isDraft: Bool
	let publishedAt: Date
	let assets: [GitHubAsset]
	
	enum CodingKeys: String, CodingKey {
		case id
		case tagName = "tag_name"
		case body
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

#Preview {
	UpdateDownloadView()
}
