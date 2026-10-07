//
//  SourcesView.swift
//  Feather
//

import CoreData
import AltSourceKit
import SwiftUI
import NimbleViews

// MARK: - View
struct SourcesView: View {
	@StateObject var viewModel = SourcesViewModel.shared
	@State private var _selectedRoute: SourceAppsView.SourceAppRoute?
	@State private var _searchText = ""
	@AppStorage("Feather.sortOptionRawValue") private var _sortOptionRawValue: String = SourceAppsView.SortOption.default.rawValue
	@AppStorage("Feather.sortAscending") private var _sortAscending: Bool = true
	@State private var _sortOption: SourceAppsView.SortOption = .default
	
	// Категории: key = значение "category" в json, title = текст на кнопке
	@State private var _selectedCategory = "all"
	private let _categories: [(key: String, title: String)] = [
		("all", "Все"),
		("social", "Соцсети"),
		("finance", "Финансыы"),
		("games", "Игры"),
		("tools", "Инструменты")
	]

	@FetchRequest(
		entity: AltSource.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
		animation: .snappy
	) private var _sources: FetchedResults<AltSource>

	var body: some View {
		NBNavigationView("Каталог") {
			VStack(spacing: 0) {
				_header
				mainContent
			}
			.navigationBarHidden(true)
			.navigationDestinationIfAvailable(item: $_selectedRoute) { route in
				SourceAppsDetailView(sourceURL: route.sourceURL, source: route.source, app: route.app)
			}
			.refreshable {
				await viewModel.fetchSources(_sources, refresh: true)
			}
		}
		.task(id: Array(_sources)) {
			await viewModel.fetchSources(_sources)
		}
		.onChange(of: _sortOption) { newValue in
			_sortOptionRawValue = newValue.rawValue
		}
	}
	
	// MARK: - Подсчёт для бейджа
	
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
	
	// Количество приложений в категории
	private func _count(for key: String) -> Int {
		let apps = Array(_sources)
			.compactMap { viewModel.sources[$0] }
			.flatMap { $0.apps }
		if key == "all" { return apps.count }
		return apps.filter { _categoryValue(of: $0) == key.lowercased() }.count
	}
	
	// MARK: - Header (закреплённая шапка как в zStore)
	private var _header: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text("Каталог")
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
										_selectedCategory == c.key ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.15),
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

	// MARK: - Subviews
	@ViewBuilder
	private var mainContent: some View {
		if !viewModel.isFinished {
			Spacer()
			ProgressView()
			Spacer()
		} else {
			contentView
		}
	}

	@ViewBuilder
	private var contentView: some View {
		let loadedSources = Array(_sources).compactMap { viewModel.sources[$0] }
		if loadedSources.isEmpty {
			emptyState
		} else {
			appsListView()
		}
	}

	@ViewBuilder
	private var emptyState: some View {
		if #available(iOS 17, *) {
			ContentUnavailableView {
				Label("Нет приложений", systemImage: "globe.desk.fill")
			} description: {
				Text("Репозиторий загружается...")
			}
		}
	}

	@ViewBuilder
	private func appsListView() -> some View {
		let contexts = Array(_sources).compactMap { source -> SourceAppsView.SourceRepositoryContext? in
			guard let repo = viewModel.sources[source] else { return nil }
			return SourceAppsView.SourceRepositoryContext(sourceURL: source.sourceURL, repository: repo)
		}
		
		TabView(selection: $_selectedCategory) {
			ForEach(_categories, id: \.key) { c in
				SourceAppsTableRepresentableView(
					sourceContexts: contexts,
					searchText: $_searchText,
					sortOption: $_sortOption,
					sortAscending: $_sortAscending,
					selectedCategory: c.key,
					onSelect: { _selectedRoute = $0 }
				)
				.ignoresSafeArea(edges: .bottom)
				.tag(c.key)
			}
		}
		.tabViewStyle(.page(indexDisplayMode: .never))
		.ignoresSafeArea(edges: .bottom)
	}

	// MARK: - Sort (кнопка сортировки убрана с экрана, функции оставлены)
	@ViewBuilder
	private var sortMenuContent: some View {
		Section("Сортировка") {
			ForEach(SourceAppsView.SortOption.allCases, id: \.displayName) { opt in
				sortButton(for: opt)
			}
		}
	}

	private func sortButton(for opt: SourceAppsView.SortOption) -> some View {
		Button {
			if _sortOption == opt {
				_sortAscending.toggle()
			} else {
				_sortOption = opt
				_sortAscending = true
			}
		} label: {
			HStack {
				Text(opt.displayName)
				if _sortOption == opt {
					Image(systemName: _sortAscending ? "chevron.up" : "chevron.down")
				}
			}
		}
	}
}
