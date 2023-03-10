import UIKit
import RxSwift
import ThemeKit
import SectionsTableView
import SnapKit
import HUD
import Chart
import ComponentKit

class MetricChartViewController: ThemeActionSheetController {
    private let viewModel: MetricChartViewModel
    private let disposeBag = DisposeBag()

    private let titleView = BottomSheetTitleView()
    private let tableView = SelfSizedSectionsTableView(style: .grouped)
    private let poweredByLabel = UILabel()

    /* Chart section */
    private let chartCell: ChartCell
    private let chartRow: StaticRow

    init(viewModel: MetricChartViewModel, configuration: ChartConfiguration) {
        self.viewModel = viewModel

        chartCell = ChartCell(viewModel: viewModel, configuration: configuration)

        chartRow = StaticRow(
                cell: chartCell,
                id: "chartView",
                height: chartCell.cellHeight
        )

        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(titleView)
        titleView.snp.makeConstraints { maker in
            maker.leading.top.trailing.equalToSuperview()
        }

        titleView.bind(
                image: .local(image: UIImage(named: "chart_2_24")?.withTintColor(.themeJacob)),
                title: viewModel.title,
                viewController: self
        )

        view.addSubview(tableView)
        tableView.snp.makeConstraints { maker in
            maker.leading.trailing.equalToSuperview()
            maker.top.equalTo(titleView.snp.bottom).offset(CGFloat.margin12)
            if viewModel.poweredBy == nil {
                maker.bottom.equalTo(view.safeAreaLayoutGuide)
            }
        }

        title = viewModel.title

        tableView.sectionDataSource = self

        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear

        tableView.registerCell(forClass: SpinnerCell.self)
        tableView.registerCell(forClass: TextCell.self)

        if let poweredBy = viewModel.poweredBy {
            view.addSubview(poweredByLabel)
            poweredByLabel.snp.makeConstraints { maker in
                maker.leading.trailing.equalToSuperview().inset(CGFloat.margin24)
                maker.top.equalTo(tableView.snp.bottom)
                maker.bottom.equalTo(view.safeAreaLayoutGuide).inset(CGFloat.margin24)
            }

            poweredByLabel.textAlignment = .center
            poweredByLabel.textColor = .themeGray
            poweredByLabel.font = .caption
            poweredByLabel.text = "Powered By \(poweredBy)"
        }

        chartRow.onReady = { [weak chartCell] in chartCell?.onLoad() }

        tableView.buildSections()
        viewModel.start()
    }

    private func reloadTable() {
        tableView.buildSections()

        tableView.beginUpdates()
        tableView.endUpdates()
    }

}

extension MetricChartViewController {

    private var chartSection: SectionProtocol {
        Section(
                id: "chart",
                footerState: viewModel.description.map { tableView.sectionFooter(text: $0) } ?? .margin(height: .margin16),
                rows: [chartRow]
        )
    }

}

extension MetricChartViewController: SectionsDataSource {

    public func buildSections() -> [SectionProtocol] {
        [chartSection]
    }

}
