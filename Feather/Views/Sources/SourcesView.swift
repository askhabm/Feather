//
//  SourcesView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
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
	@State private var _isAddingPresenting = false
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
			ZStack {
				if !viewModel.isFinished {
					ProgressView()
				} else {
					contentView
				}
			}
			.searchable(text: $_searchText, placement: .platform())
			.toolbar { toolbarContent }
			.navigationDestinationIfAvailable(item: $_selectedRoute) { route in
				SourceAppsDetailView(source: route.source, app: route.app)
			}
			.refreshable {
				await viewModel.fetchSources(_sources, refresh: true)
			}
			.sheet(isPresented: $_isAddingPresenting) {
				SourcesAddView()
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
	private var contentView: some View {
		let loadedSources = Array(_sources).compactMap { viewModel.sources[$0] }
		if loadedSources.isEmpty {
			if #available(iOS 17, *) {
				ContentUnavailableView {
					Label("Нет приложений", systemImage: "globe.desk.fill")
				} description: {
					Text("Репозиторий загружается...")
				}
			}
		} else {
			SourceAppsTableRepresentableView(
				sources: loadedSources,
				searchText: $_searchText,
				sortOption: $_sortOption,
				sortAscending: $_sortAscending,
				onSelect: { _selectedRoute = $0 }
			)
			.ignoresSafeArea()
		}
	}

	@ToolbarContentBuilder
	private var toolbarContent: some ToolbarContent {
		ToolbarItem(placement: .topBarTrailing) {
			Button(action: { _isAddingPresenting = true }) {
				Image(systemName: "plus")
			}
		}

		ToolbarItem(placement: .topBarTrailing) {
			Menu {
				Section("Сортировка") {
					ForEach(SourceAppsView.SortOption.allCases, id: \.displayName) { opt in
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
			} label: {
				Image(systemName: "line.3.horizontal.decrease")
			}
		}
	}
}
