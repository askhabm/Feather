//
//  SettingsView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import NimbleViews
import UIKit

// MARK: - View
struct SettingsView: View {
	@AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
	
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var _certificates: FetchedResults<CertificatePair>
	
	private var selectedCertificate: CertificatePair? {
		guard
			_storedSelectedCert >= 0,
			_storedSelectedCert < _certificates.count
		else {
			return nil
		}
		return _certificates[_storedSelectedCert]
	}

	// MARK: Body
	var body: some View {
		NBNavigationView("Настройки") {
			Form {
				FRSection("Сертификат") {
					if let cert = selectedCertificate {
						CertificatesCellView(cert: cert)
					} else {
						Text(.localized("Нет сертификата"))
							.font(.footnote)
							.foregroundColor(.disabled())
					}
					NavigationLink(destination: CertificatesView()) {
						Label("Добавить сертификат", systemImage: "checkmark.seal")
					}
				} footer: {
					Text("Добавьте сертификат для подписи приложений.")
				}
				
				FRSection(.localized("Доп. настройки")) {
					NavigationLink(destination: InstallationView()) {
						Label(.localized("Installation"), systemImage: "arrow.down.circle")
					}
				} footer: {
					Text(.localized("Настройки способа установки."))
				}
				
				FRSection("Наш Telegram") {
					Button {
						UIApplication.open("https://t.me/iphonmods")
					} label: {
						Label("iphonmods by makuzaewv", systemImage: "paperplane.fill")
					}
				}
			}
		}
	}
}

// MARK: - Заголовок раздела: мелкий, серый, заглавными (как в zStore)
struct FRSection<Content: View, Footer: View>: View {
	let title: String
	let content: Content
	let footer: Footer
	
	init(
		_ title: String,
		@ViewBuilder content: () -> Content,
		@ViewBuilder footer: () -> Footer
	) {
		self.title = title
		self.content = content()
		self.footer = footer()
	}
	
	var body: some View {
		Section {
			content
		} header: {
			Text(title).textCase(.uppercase)
		} footer: {
			footer
		}
	}
}

// Версия без подписи снизу
extension FRSection where Footer == EmptyView {
	init(_ title: String, @ViewBuilder content: () -> Content) {
		self.init(title, content: content, footer: { EmptyView() })
	}
}
