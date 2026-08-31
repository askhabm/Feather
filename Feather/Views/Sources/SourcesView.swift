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

	@FetchRequest(
		entity: AltSource.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
		animation: .snappy
	) private var _sources: FetchedResults<AltSource>

	var body: some View {
		NBNavigationView("Каталог") {
			mainContent
				.searchable(text: $_searchText, placement: .platform())
				.toolbar { toolbarContent }
				.navigationDestinationIfAvailable(item: $_selectedRoute) { route in
					SourceAppsDetailView(source: route.source, app: route.app)
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

	// MARK: - Subviews
	@ViewBuilder
	private var mainContent: some View {
		if !viewModel.isFinished {
			ProgressView()
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
			appsListView(loadedSources)
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
	private func appsListView(_ loadedSources: [ASRepository]) -> some View {
		SourceAppsTableRepresentableView(
			sources: loadedSources,
			searchText: $_searchText,
			sortOption: $_sortOption,
			sortAscending: $_sortAscending,
			onSelect: { _selectedRoute = $0 }
		)
		.ignoresSafeArea()
	}

	@ToolbarContentBuilder
	private var toolbarContent: some ToolbarContent {
		ToolbarItem(placement: .topBarTrailing) {
			sortMenu
		}
	}

	private var sortMenu: some View {
		Menu {
			sortMenuContent
		} label: {
			Image(systemName: "line.3.horizontal.decrease")
		}
	}

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
