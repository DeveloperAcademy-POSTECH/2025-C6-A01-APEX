//
//  ContentView.swift
//  APEX
//
//  Created by 조운경 on 9/20/25.
//

import SwiftUI

struct ContactsView: View {
    @State private var favoriteExpanded: Bool = true
    @State private var expanded: Bool = true
    @State private var showProfileAdd: Bool = false
    private let itemHeight: CGFloat = 64
    
    let favoriteClient: [Client] = sampleClients.filter({$0.favorite})
    
    private var clients: [String: [Client]] {
        Dictionary(grouping: sampleClients, by: { $0.company })
    }
    
    // Removed unused openSide maps after reverting to native swipeActions
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DisclosureGroup(isExpanded: $favoriteExpanded) {
                    List {
                        ForEach(favoriteClient) { client in
                            ListItemView(client: client)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listRowSpacing(4)
                    .listStyle(.plain)
                    .scrollDisabled(true)
                    .scrollContentBackground(.hidden)
                    .frame(height: CGFloat(favoriteClient.count) * itemHeight + CGFloat(favoriteClient.count - 1) * 4)
                } label: {
                    Text("Favorite")
                        .foregroundColor(.gray)
                        .font(.body1)
                }
                
                Divider()
                
                DisclosureGroup(isExpanded: $expanded) {
                    ForEach(clients.keys.sorted(), id: \.self) { company in
                        let clientPerCompany = clients[company] ?? []
                        HStack {
                            Text(company)
                                .foregroundColor(.gray)
                                .font(.body1)
                            Spacer()
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                        List {
                            ForEach(clientPerCompany) { client in
                                ListItemView(client: client)
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.hidden)
                            }
                        }
                        .listRowSpacing(4)
                        .listStyle(.plain)
                        .scrollDisabled(true)
                        .scrollContentBackground(.hidden)
                        .frame(
                            height: CGFloat(clientPerCompany.count) * itemHeight
                            + CGFloat(clientPerCompany.count - 1) * 4
                        )
                    }
                } label: {
                    Text("All")
                        .foregroundColor(.gray)
                }
            }
        }
        .safeAreaInset(edge: .top) {
            HeaderView(showProfileAdd: $showProfileAdd)
                .background(.white)
        }
        .sheet(isPresented: $showProfileAdd) {
            ProfileAddView()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}

#Preview {
    ContactsView()
}
