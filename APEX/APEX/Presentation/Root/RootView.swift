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
            Tab("Contacts", systemImage: "person.3.fill", value: .contacts) {
                ContactsView()
            }
            
            Tab("Notes", systemImage: "note.text", value: .search) {
                NotesView()
            }
            
            Tab(value: .search, role: .search) {
                
            }
        }
        .border(.blue, width: 3.0)
    }
}

#Preview {
    RootView()
}
