//
//  ContentView.swift
//  선택의 신
//
//  Created by …. on 2025/08/25.
//

import SwiftUI

class MenuStore: ObservableObject {
    enum DailyState { case readyToSpin, decisionMade, completed }
    
    @Published var menuItems: [String]
    @Published var points: Int
    @Published var streakCount: Int
    @Published var dailyState: DailyState = .readyToSpin
    var decidedItemToday: String?
    
    private var lastDecisionDate: Date?
    private var lastSuccessDate: Date?
    
    private let itemsKey = "com.finalProject.v6.menuItems"
    private let pointsKey = "com.finalProject.v6.points"
    private let streakKey = "com.finalProject.v6.streak"
    private let lastDateKey = "com.finalProject.v6.lastDate"
    private let lastSuccessDateKey = "com.finalProject.v6.lastSuccessDate"
    private let decidedItemKey = "com.finalProject.v6.decidedItem"

    var userLevel: (title: String, color: Color, level: Int, progress: Double, currentPoints: Int, nextLevelPoints: Int) {
        let currentPoints = self.points
        switch currentPoints {
        case 0...50:
            let basePoints = 0; let nextLevel = 50
            return ("결정 새내기 🌱", .green, 1, Double(currentPoints - basePoints) / Double(nextLevel - basePoints), currentPoints, nextLevel)
        case 51...200:
            let basePoints = 50; let nextLevel = 200
            return ("결단력 실천가 💪", .blue, 2, Double(currentPoints - basePoints) / Double(nextLevel - basePoints), currentPoints, nextLevel)
        case 201...500:
            let basePoints = 200; let nextLevel = 500
            return ("선택의 지배자 ✨", .purple, 3, Double(currentPoints - basePoints) / Double(nextLevel - basePoints), currentPoints, nextLevel)
        default:
            return ("선택의 신 👑", .orange, 4, 1.0, currentPoints, -1)
        }
    }

    init() {
        self.menuItems = UserDefaults.standard.stringArray(forKey: itemsKey) ?? ["피자 🍕", "치킨 🍗", "떡볶이 🌶️"]
        self.points = UserDefaults.standard.integer(forKey: pointsKey)
        self.streakCount = UserDefaults.standard.integer(forKey: streakKey)
        self.lastDecisionDate = UserDefaults.standard.object(forKey: lastDateKey) as? Date
        self.lastSuccessDate = UserDefaults.standard.object(forKey: lastSuccessDateKey) as? Date
        self.decidedItemToday = UserDefaults.standard.string(forKey: decidedItemKey)
        resetStateIfNeeded()
    }
    
    func resetAllData() {
        points = 0
        streakCount = 0
        dailyState = .readyToSpin
        decidedItemToday = nil
        lastDecisionDate = nil
        lastSuccessDate = nil
        saveData()
    }

    func resetStateIfNeeded() {
        if let lastDate = lastDecisionDate, !Calendar.current.isDateInToday(lastDate) {
            dailyState = .readyToSpin
            decidedItemToday = nil
        } else {
            if decidedItemToday != nil && dailyState != .readyToSpin {
                 dailyState = .completed
            }
        }
        if let lastSuccess = lastSuccessDate, Calendar.current.dateComponents([.day], from: lastSuccess, to: Date()).day ?? 0 > 1 {
            streakCount = 0
        }
        saveData()
    }

    func makeDecision() {
        guard let chosenItem = menuItems.randomElement() else { return }
        decidedItemToday = chosenItem
        lastDecisionDate = Date()
        dailyState = .decisionMade
        saveData()
    }

    func confirmActionAndGetReward() {
        points += 10
        if let lastSuccess = lastSuccessDate, Calendar.current.isDateInYesterday(lastSuccess) {
            streakCount += 1
        } else if lastSuccessDate == nil || !Calendar.current.isDateInToday(lastSuccessDate!) {
             streakCount = 1
        }
        lastSuccessDate = Date()
        dailyState = .completed
        saveData()
    }
    
    func redoDecision() {
        dailyState = .readyToSpin
        decidedItemToday = nil
        saveData()
    }

    private func saveData() {
        UserDefaults.standard.set(menuItems, forKey: itemsKey)
        UserDefaults.standard.set(points, forKey: pointsKey)
        UserDefaults.standard.set(streakCount, forKey: streakKey)
        UserDefaults.standard.set(lastDecisionDate, forKey: lastDateKey)
        UserDefaults.standard.set(lastSuccessDate, forKey: lastSuccessDateKey)
        UserDefaults.standard.set(decidedItemToday, forKey: decidedItemKey)
    }
    
    func addItem(_ item: String) { if !item.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { menuItems.append(item); saveData() } }
    func deleteItems(at offsets: IndexSet) {
        menuItems.remove(atOffsets: offsets)
        saveData()
    }
}

struct ContentView: View {
    @StateObject private var menuStore = MenuStore()
    var body: some View {
        TabView {
            RouletteView().tabItem { Label("오늘의 결정", systemImage: "flame.fill") }.environmentObject(menuStore)
            MenuManagementView().tabItem { Label("메뉴 관리", systemImage: "list.bullet") }.environmentObject(menuStore)
        }
    }
}

struct RouletteView: View {
    @EnvironmentObject var menuStore: MenuStore
    @State private var tempDisplayItem: String = ""
    @State private var isSpinning: Bool = false
    
    var body: some View {
        VStack(spacing: 15) {
            ProfileCardView(levelInfo: menuStore.userLevel, streakCount: menuStore.streakCount)
                .padding(.horizontal)
            
            Spacer()
            
            switch menuStore.dailyState {
            case .readyToSpin:
                ReadyToSpinView(isSpinning: $isSpinning, tempDisplayItem: $tempDisplayItem, hasMenuItems: !menuStore.menuItems.isEmpty) { spinRoulette() }
            case .decisionMade:
                DecisionMadeView(decidedItem: menuStore.decidedItemToday ?? "오류") { menuStore.confirmActionAndGetReward() }
            case .completed:
                CompletedView(decidedItem: menuStore.decidedItemToday ?? "오류") { menuStore.redoDecision() }
            }
            
            Spacer()
        }
        .onAppear { menuStore.resetStateIfNeeded() }
    }
    
    private func spinRoulette() {
        guard !menuStore.menuItems.isEmpty else { return }
        isSpinning = true; var spinCount = 0
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            withAnimation { tempDisplayItem = menuStore.menuItems.randomElement() ?? "" }
            spinCount += 1
            if spinCount >= 15 {
                timer.invalidate(); isSpinning = false
                menuStore.makeDecision()
            }
        }
    }
}

struct ProfileCardView: View {
    let levelInfo: (title: String, color: Color, level: Int, progress: Double, currentPoints: Int, nextLevelPoints: Int)
    let streakCount: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(levelInfo.title).font(.system(size: 22, weight: .bold)).foregroundColor(levelInfo.color)
                Spacer()
                Text("🔥 연속 \(streakCount)일").font(.headline).foregroundColor(.orange).padding(.horizontal, 10).padding(.vertical, 5).background(Color.orange.opacity(0.15)).cornerRadius(20)
            }
            Text("LV.\(levelInfo.level) (\(levelInfo.currentPoints)점)").font(.subheadline).fontWeight(.semibold).foregroundColor(.gray)
            ProgressView(value: levelInfo.progress).progressViewStyle(LinearProgressViewStyle(tint: levelInfo.color))
            HStack {
                Spacer()
                if levelInfo.nextLevelPoints != -1 {
                    Text("다음 레벨까지 \(levelInfo.nextLevelPoints - levelInfo.currentPoints)점 남음").font(.caption).foregroundColor(.gray)
                } else {
                    Text("최고 레벨입니다!").font(.caption).foregroundColor(.gray)
                }
            }
        }.padding().background(Color(.systemBackground)).cornerRadius(15).shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct ReadyToSpinView: View {
    @Binding var isSpinning: Bool; @Binding var tempDisplayItem: String
    var hasMenuItems: Bool
    var spinAction: () -> Void
    var body: some View { VStack(spacing: 20) {
        if !hasMenuItems {
            Image(systemName: "list.bullet.clipboard.fill").font(.system(size: 60)).foregroundColor(.gray)
            Text("메뉴를 먼저 추가해주세요.").font(.largeTitle).fontWeight(.bold).multilineTextAlignment(.center).padding(.horizontal)
            Text("'메뉴 관리' 탭에서 오늘의 선택지를 등록할 수 있습니다.").font(.subheadline).foregroundColor(.gray)
        } else {
            Text("오늘의 결정을 시작하세요!").font(.largeTitle).fontWeight(.bold).multilineTextAlignment(.center)
            Text(isSpinning ? tempDisplayItem : "❓").font(.system(size: 60, weight: .bold)).frame(minHeight: 100).id(tempDisplayItem).transition(.opacity)
            Button(action: spinAction) {
                Text(isSpinning ? "결정 중..." : "룰렛 돌리기!").font(.title).fontWeight(.bold).foregroundColor(.white).padding().frame(width: 250, height: 60).background(isSpinning ? Color.gray : Color.blue).cornerRadius(30).shadow(radius: 5)
            }.disabled(isSpinning)
        }
    }}
}

struct DecisionMadeView: View {
    var decidedItem: String; var confirmAction: () -> Void
    var body: some View { VStack(spacing: 15) {
        Text("오늘의 결정은?").font(.title)
        Text(decidedItem).font(.system(size: 50, weight: .bold)).foregroundColor(.green).padding().multilineTextAlignment(.center)
        Text("결정을 실천하고 보상을 받으세요!").font(.subheadline).foregroundColor(.gray)
        Button(action: confirmAction) {
            Text("실천 완료! (+10점)").font(.title).fontWeight(.bold).foregroundColor(.white).padding().frame(width: 280, height: 60).background(Color.green).cornerRadius(30).shadow(radius: 5)
        }
    }}
}

struct CompletedView: View {
    var decidedItem: String; var redoAction: () -> Void
    var body: some View { VStack(spacing: 15) {
        Image(systemName: "checkmark.seal.fill").font(.system(size: 60)).foregroundColor(.green)
        Text("미션 완료!").font(.largeTitle).fontWeight(.bold)
        Text("실천 항목: \(decidedItem)").font(.headline).padding(.top, 5)
        Button(action: redoAction) {
            Label(
                title: { Text("다른 결정하기").fontWeight(.bold) },
                icon: { Image(systemName: "arrow.clockwise") }
            ).font(.title2).foregroundColor(.white).padding().frame(width: 280, height: 55).background(Color.orange).cornerRadius(30).shadow(radius: 5)
        }.padding(.top, 20)
    }}
}

struct MenuManagementView: View {
    @EnvironmentObject var menuStore: MenuStore; @State private var newItem: String = ""
    var body: some View { NavigationView { VStack {
        HStack {
            TextField("새 메뉴 추가", text: $newItem).textFieldStyle(RoundedBorderTextFieldStyle()).padding([.leading])
            Button("추가", action: addItemAndClear).padding(.horizontal)
        }.padding(.top)
        List { ForEach(menuStore.menuItems, id: \.self) { item in Text(item) }.onDelete(perform: menuStore.deleteItems) }
    }.navigationTitle("메뉴 관리") }}
    private func addItemAndClear() { menuStore.addItem(newItem); newItem = "" }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
