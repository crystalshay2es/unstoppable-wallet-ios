import UIKit
import ThemeKit
import EvmKit
import OneInchKit

struct SwapConfirmationModule {

    static func viewController(sendData: SendEvmData, dex: SwapModule.Dex) -> UIViewController? {
        guard let evmKitWrapper =  App.shared.evmBlockchainManager.evmKitManager(blockchainType: dex.blockchainType).evmKitWrapper else {
            return nil
        }

        guard let coinServiceFactory = EvmCoinServiceFactory(
                blockchainType: dex.blockchainType,
                marketKit: App.shared.marketKit,
                currencyKit: App.shared.currencyKit,
                evmBlockchainManager: App.shared.evmBlockchainManager,
                coinManager: App.shared.coinManager
        ) else {
            return nil
        }

        let (settingsService, feeViewModel) = EvmSendSettingsModule.instance(
                evmKit: evmKitWrapper.evmKit, blockchainType: evmKitWrapper.blockchainType, sendData: sendData, coinServiceFactory: coinServiceFactory,
                gasLimitSurchargePercent: 20
        )

        let service = SendEvmTransactionService(sendData: sendData, evmKitWrapper: evmKitWrapper, settingsService: settingsService, evmLabelManager: App.shared.evmLabelManager)
        let viewModel = SendEvmTransactionViewModel(service: service, coinServiceFactory: coinServiceFactory, cautionsFactory: SendEvmCautionsFactory(), evmLabelManager: App.shared.evmLabelManager)

        return SwapConfirmationViewController(transactionViewModel: viewModel, settingsService: settingsService, feeViewModel: feeViewModel)
    }

    static func viewController(parameters: OneInchSwapParameters, dex: SwapModule.Dex) -> UIViewController? {
        guard let evmKitWrapper =  App.shared.evmBlockchainManager.evmKitManager(blockchainType: dex.blockchainType).evmKitWrapper else {
            return nil
        }

        guard let swapKit = try? OneInchKit.Kit.instance(evmKit: evmKitWrapper.evmKit) else {
            return nil
        }

        let oneInchProvider = OneInchProvider(swapKit: swapKit)

        guard let coinServiceFactory = EvmCoinServiceFactory(
                blockchainType: dex.blockchainType,
                marketKit: App.shared.marketKit,
                currencyKit: App.shared.currencyKit,
                evmBlockchainManager: App.shared.evmBlockchainManager,
                coinManager: App.shared.coinManager
        ) else {
            return nil
        }

        let gasPriceService = EvmFeeModule.gasPriceService(evmKit: evmKitWrapper.evmKit)
        let feeService = OneInchFeeService(evmKit: evmKitWrapper.evmKit,  provider: oneInchProvider, gasPriceService: gasPriceService, coinService: coinServiceFactory.baseCoinService, parameters: parameters)
        let service = OneInchSendEvmTransactionService(evmKitWrapper: evmKitWrapper, transactionFeeService: feeService)
        let nonceService = NonceService(evmKit: evmKitWrapper.evmKit, replacingNonce: nil)
        let settingsService = EvmSendSettingsService(feeService: feeService, nonceService: nonceService)

        let transactionViewModel = SendEvmTransactionViewModel(service: service, coinServiceFactory: coinServiceFactory, cautionsFactory: SendEvmCautionsFactory(), evmLabelManager: App.shared.evmLabelManager)
        let feeViewModel = EvmFeeViewModel(service: feeService, gasPriceService: gasPriceService, coinService: coinServiceFactory.baseCoinService)

        return SwapConfirmationViewController(transactionViewModel: transactionViewModel, settingsService: settingsService, feeViewModel: feeViewModel)
    }

}
