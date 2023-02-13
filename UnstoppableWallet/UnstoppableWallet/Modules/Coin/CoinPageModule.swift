import UIKit
import LanguageKit
import ThemeKit
import MarketKit

struct CoinPageModule {

    static func viewController(coinUid: String) -> UIViewController? {
        guard let fullCoin = try? App.shared.marketKit.fullCoins(coinUids: [coinUid]).first else {
            return nil
        }

        let service = CoinPageService(
                fullCoin: fullCoin,
                favoritesManager: App.shared.favoritesManager
        )

        let viewModel = CoinPageViewModel(service: service)

        let overviewController = CoinOverviewModule.viewController(coinUid: coinUid)
        let marketsController = CoinMarketsModule.viewController(coin: fullCoin.coin)
        let detailsController = CoinDetailsModule.viewController(fullCoin: fullCoin)
        let tweetsController = CoinTweetsModule.viewController(fullCoin: fullCoin)

        let viewController = CoinPageViewController(
                viewModel: viewModel,
                overviewController: overviewController,
                marketsController: marketsController,
                detailsController: detailsController,
                tweetsController: tweetsController
        )

        return ThemeNavigationController(rootViewController: viewController)
    }

}

extension CoinPageModule {

    enum Tab: Int, CaseIterable {
        case overview
        case details
        case markets
        case tweets

        var title: String {
            switch self {
            case .overview: return "coin_page.tab.overview".localized
            case .details: return "coin_page.tab.details".localized
            case .markets: return "coin_page.tab.markets".localized
            case .tweets: return "coin_page.tab.tweets".localized
            }
        }
    }

}
