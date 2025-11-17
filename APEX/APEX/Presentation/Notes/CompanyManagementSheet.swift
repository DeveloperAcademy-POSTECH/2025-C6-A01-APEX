//
//  CompanyManagementSheet.swift
//  APEX
//
//  Created by Mr.Penguin on 11/14/25.
//

import SwiftUI

struct CompanyManagementSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var clientsStore: ClientsStore
    @State private var sortByAlphabet: Bool = true
    @State private var enabledCompanies: Set<String> = []
    @State private var companyOrder: [String] = []
    
    // MARK: - Persistence Keys
    private let enabledCompaniesDefaultsKey = "apex.notes.enabledCompanies"
    private let companyOrderDefaultsKey = "apex.notes.companyOrder"
    
    var body: some View {
        ZStack {
            Color("Background")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 네비게이션 바
                navigationBar
                
                // 정렬 토글
                sortToggleSection
                
                // 회사 리스트
                companyListSection
                    .onAppear {
                        loadPreferencesIfNeeded()
                        reconcileEnabledWithAllCompanies()
                    }
                
                Spacer()
            }
        }
    }
    
    private var navigationBar: some View {
        ZStack {
            // 버튼들 레이아웃
            HStack(spacing: 0) {
                // 닫기 버튼
                Button(action: {
                    isPresented = false
                }, label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .medium, design: .default))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                        )
                        .contentShape(Circle())
                })
                .buttonStyle(.plain)
                .padding(.leading, 16)
                
                Spacer()
                
                // 완료 버튼
                Button(action: {
                    isPresented = false
                }, label: {
                    Text("완료")
                        .font(.title6)
                        .foregroundColor(.black)
                        .frame(width: 52, height: 44)
                        .background(
                            Capsule()
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                        )
                })
                .buttonStyle(.plain)
                .padding(.trailing, 16)
            }
            
            // 제목을 절대 가운데에 배치
            Text("회사 관리")
                .font(.title5)
                .foregroundColor(.black)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
        .background(Color("Background"))
    }
    
    private var sortToggleSection: some View {
        HStack {
            Spacer()
            
            // Pill-style segmented control with animated glass effect
            ZStack {
                // 컨테이너 배경
                RoundedRectangle(cornerRadius: 19)
                    .fill(Color("PrimaryContainer"))
                    .frame(width: 192, height: 38)
                
                // 애니메이션되는 플랫 타원
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("Background"))
                    .frame(width: 92, height: 32)
                    .offset(x: sortByAlphabet ? -48 : 48) // 왼쪽(-48) 또는 오른쪽(+48)으로 이동
                    .animation(.easeInOut(duration: 0.3), value: sortByAlphabet)
                
                // 버튼들 (투명한 배경)
                HStack(spacing: 0) {
                    // 가나다 순 버튼
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            sortByAlphabet = true
                        }
                    }, label: {
                        Text("가나다 순")
                            .font(.caption1)
                            .foregroundColor(sortByAlphabet ? Color("BlackLabel") : Color("GrayLabel"))
                            .frame(width: 96, height: 38)
                    })
                    .buttonStyle(.plain)
                    
                    // 사용자 설정 순 버튼  
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            sortByAlphabet = false
                        }
                    }, label: {
                        Text("사용자 설정 순")
                            .font(.caption1)
                            .foregroundColor(!sortByAlphabet ? Color("BlackLabel") : Color("GrayLabel"))
                            .frame(width: 96, height: 38)
                    })
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 192, height: 38)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
    
    private var companyListSection: some View {
        List {
            ForEach(sortedEnabledCompanies, id: \.self) { company in
                CompanyRowView(
                    company: company,
                    isEnabled: true,
                    canReorder: !sortByAlphabet,
                    onToggle: { toggleCompany(company) }
                )
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color(.systemBackground).opacity(0))
            }
            .onMove(perform: sortByAlphabet ? nil : { source, destination in
                moveEnabledCompany(from: source, to: destination)
            })
            
            ForEach(sortedAvailableCompanies, id: \.self) { company in
                CompanyRowView(
                    company: company,
                    isEnabled: false,
                    canReorder: false,
                    onToggle: { toggleCompany(company) }
                )
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color(.systemBackground).opacity(0))
            }
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Derived Data
    private var allCompanies: Set<String> {
        Set(
            clientsStore.clients.compactMap { client in
                let trimmed = client.company.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        )
    }
    
    private var sortedEnabledCompanies: [String] {
        let companies = Array(enabledCompanies)
        if sortByAlphabet {
            return companies.sorted { $0.localizedCompare($1) == .orderedAscending }
        } else {
            return companyOrder.filter { enabledCompanies.contains($0) }
        }
    }
    
    private var sortedAvailableCompanies: [String] {
        let available = allCompanies.subtracting(enabledCompanies)
        return Array(available).sorted { $0.localizedCompare($1) == .orderedAscending }
    }
    
    private func toggleCompany(_ company: String) {
        if enabledCompanies.contains(company) {
            enabledCompanies.remove(company)
            companyOrder.removeAll { $0 == company }
        } else {
            enabledCompanies.insert(company)
            // Append to order only if using manual order; otherwise will be sorted by alpha
            if !companyOrder.contains(company) {
                companyOrder.append(company)
            }
        }
        persistPreferences()
    }
    
    private func moveEnabledCompany(from source: IndexSet, to destination: Int) {
        guard !sortByAlphabet else { return }
        companyOrder.move(fromOffsets: source, toOffset: destination)
        persistPreferences()
    }
    
    // MARK: - Persistence
    private func loadPreferencesIfNeeded() {
        // Load enabled companies
        if let rawEnabled = UserDefaults.standard.array(forKey: enabledCompaniesDefaultsKey) as? [String] {
            enabledCompanies = Set(rawEnabled)
        } else {
            // Default: enable all companies on first run
            enabledCompanies = allCompanies
        }
        
        // Load order
        if let rawOrder = UserDefaults.standard.array(forKey: companyOrderDefaultsKey) as? [String] {
            companyOrder = rawOrder
        } else {
            companyOrder = Array(allCompanies).sorted { $0.localizedCompare($1) == .orderedAscending }
        }
    }
    
    private func persistPreferences() {
        let enabledArray = Array(enabledCompanies)
        UserDefaults.standard.set(enabledArray, forKey: enabledCompaniesDefaultsKey)
        UserDefaults.standard.set(companyOrder, forKey: companyOrderDefaultsKey)
    }
    
    private func reconcileEnabledWithAllCompanies() {
        // Remove non-existing companies from enabled/order
        let removed = enabledCompanies.subtracting(allCompanies)
        if !removed.isEmpty {
            enabledCompanies.subtract(removed)
        }
        companyOrder = companyOrder.filter { allCompanies.contains($0) }
        // Add new companies discovered to the end of order
        let newOnes = allCompanies.subtracting(Set(companyOrder))
        if !newOnes.isEmpty {
            companyOrder.append(contentsOf: newOnes.sorted { $0.localizedCompare($1) == .orderedAscending })
        }
        persistPreferences()
    }
}

struct CompanyRowView: View {
    let company: String
    let isEnabled: Bool
    let canReorder: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Text(company)
                .font(.body2)
                .foregroundColor(isEnabled ? Color("BlackLabel") : Color("GrayLabel"))
            
            Spacer()
            
            // 토글 버튼
            Button(action: onToggle, label: {
                Image(systemName: isEnabled ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(isEnabled ? Color("Error") : Color("GreenLabel"))
            })
            .buttonStyle(.plain)
            
            // 드래그 핸들 (사용자 설정 순이고 활성화된 회사만) - +/- 버튼 우측에 배치
            if canReorder && isEnabled {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("BlackLabel"))
            }
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    CompanyManagementSheet(isPresented: .constant(true))
        .environmentObject(ClientsStore.shared)
}
