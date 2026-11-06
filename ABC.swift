import SwiftUI

// 既存の MainContainerView を前提とした修正例
struct PrimeMainContainerView: View {
    @State private var showPrimes = false

    // 既存で CubeCell の配列や現在表示中のセルを管理していることを想定
    // 例として、selectedCell という CubeCell を State または Binding で保持している想定
    @Binding var selectedCell: CubeCell?

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Toggle("素因数表示", isOn: $showPrimes)
                    .toggleStyle(SwitchToggleStyle())
                    .foregroundColor(.yellow)
                    .padding(.trailing, 24)
            }
            ZStack {
                if let cell = selectedCell {
                    UnifiedCubeCellView(
                        cell: cell,
                        element: nil,
                        gridSize: (cellWidth: 0, cellHeight: 0),
                        soundVM: DummySwitchViewModel(),
                        selectedCellIDs: .constant([]),
                        selectedScatSymbol: .constant("-")
                    )
                    if showPrimes {
                        PrimeOverlayView(cell: cell)
                    }
                } else {
                    Text("セルが選択されていません")
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            // 適宜初期セルをセット
            if selectedCell == nil {
                // ここで初期の CubeCell を設定
                // 例: selectedCell = someDefaultCubeCell
            }
        }
    }
}

// 素因数分解関数はそのまま残す
func primeFactors(of number: Int) -> [Int] {
    var n = number
    var factors: [Int] = []
    var divisor = 2
    while n > 1 {
        if n % divisor == 0 {
            if !factors.contains(divisor) {
                factors.append(divisor)
            }
            n /= divisor
        } else {
            divisor += 1
        }
    }
    return factors
}

struct PrimeOverlayView: View {
    let cell: CubeCell
    var body: some View {
        let factors = primeFactors(of: cell.number)
        Text(factors.isEmpty ? "" : factors.map { String($0) }.joined(separator: ","))
            .font(.caption2)
            .foregroundColor(.white)
            .padding(2)
            .background(Color.black.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}


class DummySoundViewModel: ObservableObject {
    // 実際の SoundViewModel の代用。必要に応じて差し替えてください。
}

// SwitchViewModel の仮実装
class DummyCubicModel: CubicModel {}
class DummyMappingModel: MappingModel {
    init() {
        super.init(cubicModel: DummyCubicModel())
    }
}

class DummySwitchViewModel: SwitchViewModel {
    @Published var selectedCell: CubeCell? = nil

    init() {
        super.init(
            cubeVM: DummyCubicModel(),
            mappingModel: DummyMappingModel()
        )
    }
}
