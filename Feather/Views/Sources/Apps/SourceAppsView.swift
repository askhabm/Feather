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
	
	// Категории: key = значени "category" в json, title = текст на кнопке
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
	
	// Читает поле "category" так же, как таблица (через Mirror)
	private func _categoryValue(of app: ASRepository.App) -> String {
		guard let child = Mirror(reflecting: app).children.first(where: { $0.label == "category" }) else {
			return ""
		}
		var value: Any = child.value
		let mirror = Mirror(reflecting: value)
		if mirror.displayStyle == .optional {
			guard let inner = mirror.children.first?.value else { return "" }
			value = inner
		}
		return "\(value)".lowercased()
	}
	
	// Количество приложений в категории (для красного бейджа)
	private func _count(for key: String) -> Int {
		let apps = (_sourceContexts ?? []).flatMap { $0.repository.apps }
		if key == "all" { return apps.count }
		return apps.filter { _categoryValue(of: $0) == key.lowercased() }.count
	}
	
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
			
			ScrollViewReader { proxy in
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 8) {
						ForEach(_categories, id: \.key) { c in
							Button {
								withAnimation(.easeInOut(duration: 0.25)) {
									_selectedCategory = c.key
								}
							} label: {
								Text(c.title)
									.font(.subheadline.weight(.semibold))
									.padding(.horizontal, 14)
									.padding(.vertical, 8)
									.background(
										_selectedCategory == c.key ? Color.accentColor.opacity(0.15) : Color.clear,
										in: Capsule()
									)
									.overlay(alignment: .topTrailing) {
										if _selectedCategory == c.key {
											Text("\(_count(for: c.key))")
												.font(.caption2.bold())
												.foregroundStyle(.white)
												.padding(.horizontal, 6)
												.padding(.vertical, 2)
												.background(Color.red, in: Capsule())
												.offset(x: 6, y: -6)
										}
									}
							}
							.buttonStyle(.plain)
							.id(c.key)
						}
					}
					.padding(.horizontal, 8)
					.padding(.top, 10)
				}
				.onChange(of: _selectedCategory) { key in
					withAnimation { proxy.scrollTo(key, anchor: .center) }
				}
			}
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
					TabView(selection: $_selectedCategory) {
						ForEach(_categories, id: \.key) { c in
							SourceAppsTableRepresentableView(
								sourceContexts: _sourceContexts,
								searchText: $_searchText,
								sortOption: $_sortOption,
								sortAscending: $_sortAscending,
								selectedCategory: c.key,
								onSelect: { self._selectedRoute = $0 }
							)
							.ignoresSafeArea(edges: .bottom)
							.tag(c.key)
						}
					}
					.tabViewStyle(.page(indexDisplayMode: .never))
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
			_sortOption = .default
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
