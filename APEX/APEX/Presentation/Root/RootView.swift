//
//  RootView.swift
//  APEX
//
//  Created by 조운경 on 10/18/25.
//

import SwiftUI

struct RootView: View {
    enum Tabs { case contacts, notes, search }
    
    @State private var selection: Tabs = .contacts
    
    @State private var contactsQuery: String = ""
    @State private var notesQuery: String = ""
    
    var body: some View {
        TabView(selection: $selection) {
            ContactsView()
                .tabItem {
                    Label("Contacts", systemImage: "person.3.fill")
                }
                .tag(Tabs.contacts)

            NotesView()
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }
                .tag(Tabs.notes)

            // Fallback search tab for iOS 17-style API
            Text("")
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(Tabs.search)
        }
    }
}

#Preview {
    RootView()
}
