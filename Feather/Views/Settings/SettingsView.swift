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
				NBSection("Сертификат") {
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
			}
		}
	}
}
