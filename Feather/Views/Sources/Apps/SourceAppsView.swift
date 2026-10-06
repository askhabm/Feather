//
//  SourceAppsView.swift
//  Feather
//
//  Created by samara on 1.05.2025.
//

import SwiftUI
import AltSourceKit
import NimbleViews
import UIKit

// MARK: - Extension: View (Enil)
extension SourceAppsView {
	enum SortOption: String, CaseIterable {
		case `default` = "default"
		case name
		case date
		
		var displayName: String {
			switch self {
			case .default:  .localized("Default")
			case .name: 	.localized("Name")
			case .date: 	.localized("Date")
			}
		}
	}
}

// MARK: - View
struct SourceAppsView: View {
	@AppStorage("Feather.sortOptionRawValue") private var _sortOptionRawValue: String = SortOption.default.rawValue
	@AppStorage("Feather.sortAscending") private var _sortAscending: Bool = true
	
	@State private var _sortOption: SortOption = .default
	@State private var _selectedRoute: SourceAppRoute?
	
	@State var isLoading = true
	@State var hasLoadedOnce = false
	@State private var _searchText = ""
	
	// Категории: key = значение "category" в json, title = текст на кнопке
	@State private var _selectedCategory = "all"
	private let _categories: [(key: String, title: String)] = [
		("all", "Все"),
		("social", "Соц.Сети"),
		("finance", "Финансы"),
		("games", "Игры"),
		("tools", "Инструменты")
	]

	private var _navigationTitle: String {
		if object.count == 1 {
			object[0].name ?? .localized("Unknown")
		} else {
			.localized("%lld Sources", arguments: object.count)
		}
	}
	
	var object: [AltSource]
	@ObservedObject var viewModel: SourcesViewModel
	@State private var _sourceContexts: [SourceRepositoryContext]?
	
	// MARK: Header (закреплённая шапка как в zStore)
	private var _header: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(_navigationTitle)
				.font(.largeTitle.bold())
			Text("Приложения для твоего iPhone")
				.font(.subheadline)
				.foregroundStyle(.secondary)
			
			HStack(spacing: 8) {
				Image(systemName: "magnifyingglass")
					.foregroundStyle(.secondary)
				TextField("Поиск приложений", text: $_searchText)
					.autocorrectionDisabled()
			}
			.padding(10)
			.background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
			.padding(.top, 8)
			
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 8) {
					ForEach(_categories, id: \.key) { c in
						Button {
							_selectedCategory = c.key
						} label: {
							Text(c.title)
								.font(.subheadline.weight(.semibold))
								.padding(.horizontal, 14)
								.padding(.vertical, 8)
								.background(
									_selectedCategory == c.key ? Color.accentColor.opacity(0.15) : Color.clear,
									in: Capsule()
								)
						}
						.buttonStyle(.plain)
					}
				}
			}
			.padding(.top, 4)
		}
		.padding(.horizontal, 16)
		.padding(.top, 8)
		.padding(.bottom, 8)
	}
	
	// MARK: Body
	var body: some View {
		VStack(spacing: 0) {
			_header
			
			ZStack {
				if
					let _sourceContexts,
					!_sourceContexts.isEmpty
				{
					SourceAppsTableRepresentableView(
						sourceContexts: _sourceContexts,
						searchText: $_searchText,
						sortOption: $_sortOption,
						sortAscending: $_sortAscending,
						selectedCategory: _selectedCategory,
						onSelect: { self._selectedRoute = $0 }
					)
					.ignoresSafeArea(edges: .bottom)
				} else {
					ProgressView()
				}
			}
		}
		.navigationBarHidden(true)
		.onAppear {
			if !hasLoadedOnce, viewModel.isFinished {
				_load()
				hasLoadedOnce = true
			}
			_sortOption = SortOption(rawValue: _sortOptionRawValue) ?? .default
		}
		.onChange(of: viewModel.isFinished) { _ in
			_load()
		}
		.onChange(of: _sortOption) { newValue in
			_sortOptionRawValue = newValue.rawValue
		}
		.navigationDestinationIfAvailable(item: $_selectedRoute) { route in
			SourceAppsDetailView(
				sourceURL: route.sourceURL,
				source: route.source,
				app: route.app
			)
		}
	}
	
	private func _load() {
		isLoading = true
		
		Task {
			let loadedSources = object.compactMap { source -> SourceRepositoryContext? in
				guard let repository = viewModel.sources[source] else { return nil }
				return SourceRepositoryContext(sourceURL: source.sourceURL, repository: repository)
			}
			_sourceContexts = loadedSources
			withAnimation(.easeIn(duration: 0.2)) {
				isLoading = false
			}
		}
	}
	
	struct SourceRepositoryContext: Equatable {
		let sourceURL: URL?
		let repository: ASRepository
		
		static func == (lhs: SourceRepositoryContext, rhs: SourceRepositoryContext) -> Bool {
			lhs.sourceURL == rhs.sourceURL &&
			lhs.repository.id == rhs.repository.id &&
			lhs.repository.name == rhs.repository.name &&
			lhs.repository.apps.map { "\($0.currentUniqueId)|\($0.currentVersion ?? "")" } ==
			rhs.repository.apps.map { "\($0.currentUniqueId)|\($0.currentVersion ?? "")" }
		}
	}
	
	struct SourceAppRoute: Identifiable, Hashable {
		let sourceURL: URL?
		let source: ASRepository
		let app: ASRepository.App
		let id: String = UUID().uuidString
	}
}

// MARK: - Extension: View (Sort)
extension SourceAppsView {
	@ViewBuilder
	private func _sortActions() -> some View {
		Section(.localized("Filter by")) {
			ForEach(SortOption.allCases, id: \.displayName) { opt in
				_sortButton(for: opt)
			}
		}
	}
	
	private func _sortButton(for option: SortOption) -> some View {
		Button {
			if _sortOption == option {
				_sortAscending.toggle()
			} else {
				_sortOption = option
				_sortAscending = true
			}
		} label: {
			HStack {
				Text(option.displayName)
				Spacer()
				if _sortOption == option {
					Image(systemName: _sortAscending ? "chevron.up" : "chevron.down")
				}
			}
		}
	}
}

import SwiftUI

extension View {
	@ViewBuilder
	func navigationDestinationIfAvailable<Item: Identifiable & Hashable, Destination: View>(
		item: Binding<Item?>,
		@ViewBuilder destination: @escaping (Item) -> Destination
	) -> some View {
		if #available(iOS 17, *) {
			self.navigationDestination(item: item, destination: destination)
		} else {
			self
		}
	}
}
