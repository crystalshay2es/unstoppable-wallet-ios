import Foundation

class SendPresenter {
    weak var view: ISendView?

    private let interactor: ISendInteractor
    private let router: ISendRouter
    private let factory: ISendStateViewItemFactory
    private let userInput: SendUserInput

    private let amountItem = AmountItem()
    private let addressItem = SAddressItem()
    private let feeItem = SFeeItem(isFeeAdjustable: true)
    private let sendButtonItem = SButtonItem()

    init(interactor: ISendInteractor, router: ISendRouter, factory: ISendStateViewItemFactory, userInput: SendUserInput) {
        self.interactor = interactor
        self.router = router
        self.factory = factory
        self.userInput = userInput
    }

    private func onChange(address: String?) {
        userInput.address = address

        let state = interactor.state(forUserInput: userInput)
        let viewItem = factory.viewItem(forState: state, forceRoundDown: false)

        addressItem.addressInfo = viewItem.addressInfo
        addressItem.bind?()
        amountItem.amountInfo = viewItem.amountInfo
        amountItem.bindAmount?()

        feeItem.feeInfo = viewItem.feeInfo
        feeItem.bind?()

        sendButtonItem.sendButtonEnabled = viewItem.sendButtonEnabled
        sendButtonItem.bind?()
    }

    private func updateViewItem() {
        let state = interactor.state(forUserInput: userInput)
        let viewItem = factory.viewItem(forState: state, forceRoundDown: false)

        amountItem.decimal = viewItem.decimal
        amountItem.amountInfo = viewItem.amountInfo
        amountItem.switchButtonEnabled = viewItem.switchButtonEnabled
        amountItem.hintInfo = viewItem.hintInfo
        amountItem.bind?()

        feeItem.feeInfo = viewItem.feeInfo
        feeItem.bind?()
    }

}

extension SendPresenter: ISendInteractorDelegate {

    func didRetrieve(rate: Rate?) {
        if userInput.inputType == .currency && rate == nil {
            router.dismiss()
            return
        }

        if interactor.defaultInputType == .currency && userInput.amount == 0 {
            userInput.inputType = interactor.defaultInputType
        }

        updateViewItem()
    }

    func didRetrieveFeeRate() {
        updateViewItem()
    }

    func didSend() {
        view?.dismissWithSuccess()
    }

    func didFailToSend(error: Error) {
        view?.show(error: error)
    }

    func onBecomeActive() {
        interactor.retrieveRate()
    }

}

extension SendPresenter: ISendViewDelegate {

    func showKeyboard() {
        amountItem.showKeyboard?()
    }

    var isFeeAdjustable: Bool {
        return true
    }
    var sendItems: [SendItem] {
        return [amountItem, addressItem, feeItem, sendButtonItem]
    }

    func onViewDidLoad() {
        amountItem.delegate = self
        addressItem.delegate = self
        feeItem.delegate = self
        sendButtonItem.delegate = self

        interactor.retrieveRate()

        userInput.inputType = interactor.defaultInputType

        let state = interactor.state(forUserInput: userInput)
        let viewItem = factory.viewItem(forState: state, forceRoundDown: false)

        view?.set(coin: interactor.coin)

        amountItem.amountInfo = viewItem.amountInfo
        amountItem.switchButtonEnabled = viewItem.switchButtonEnabled
        amountItem.hintInfo = viewItem.hintInfo

        addressItem.addressInfo = viewItem.addressInfo
        feeItem.feeInfo = viewItem.feeInfo

        sendButtonItem.sendButtonEnabled = viewItem.sendButtonEnabled
        sendButtonItem.bind?()
    }

    func onClose() {
        router.dismiss()
    }

    func onAmountChanged(amount: Decimal) {
    }

    func onSwitchClicked() {
        guard let convertedAmount = interactor.convertedAmount(forInputType: userInput.inputType, amount: userInput.amount) else {
            return
        }

        let newInputType: SendInputType = userInput.inputType == .currency ? .coin : .currency

        userInput.amount = convertedAmount
        userInput.inputType = newInputType

        let state = interactor.state(forUserInput: userInput)
        let viewItem = factory.viewItem(forState: state, forceRoundDown: false)

        amountItem.decimal = viewItem.decimal
        amountItem.amountInfo = viewItem.amountInfo
        amountItem.hintInfo = viewItem.hintInfo
        amountItem.bind?()

        feeItem.feeInfo = viewItem.feeInfo
        feeItem.bind?()

        interactor.set(inputType: newInputType)
    }

    private func onAddressEnter(address: String) {
        let paymentAddress = interactor.parse(paymentAddress: address)

        if let amount = paymentAddress.amount {
            userInput.amount = amount
        }
        onChange(address: paymentAddress.address)
    }

    func onPasteAddressClicked() {
        if let address = interactor.valueFromPasteboard {
            onAddressEnter(address: address)
        }
    }

    func onConfirmClicked() {
        view?.showProgress()
        interactor.send(userInput: userInput)
    }

    func onCopyAddress() {
        guard let address = userInput.address else {
            return
        }

        interactor.copy(address: address)
        view?.showCopied()
    }

    func onMaxClicked() {
        let totalBalanceMinusFee = interactor.totalBalanceMinusFee(forInputType: userInput.inputType, address: userInput.address, feeRatePriority: userInput.feeRatePriority)
        userInput.amount = totalBalanceMinusFee

        let state = interactor.state(forUserInput: userInput)
        let viewItem = factory.viewItem(forState: state, forceRoundDown: true)

        amountItem.amountInfo = viewItem.amountInfo
        amountItem.hintInfo = viewItem.hintInfo
        amountItem.bind?()

        feeItem.feeInfo = viewItem.feeInfo
        feeItem.bind?()
    }

    func onPasteAmountClicked() {
    }

}

extension SendPresenter: ISendAmountDelegate {

    func onChanged(amount: Decimal) {
        userInput.amount = amount

        let state = interactor.state(forUserInput: userInput)
        let viewItem = factory.viewItem(forState: state, forceRoundDown: false)

        amountItem.hintInfo = viewItem.hintInfo
        amountItem.bindHint?()

        feeItem.feeInfo = viewItem.feeInfo
        feeItem.bind?()

        sendButtonItem.sendButtonEnabled = viewItem.sendButtonEnabled
        sendButtonItem.bind?()
    }

    func onPasteClicked() {
        if let value = ValueFormatter.instance.parseAnyDecimal(from: interactor.valueFromPasteboard) {
            userInput.amount = value

            let state = interactor.state(forUserInput: userInput)
            let viewItem = factory.viewItem(forState: state, forceRoundDown: false)

            amountItem.amountInfo = viewItem.amountInfo
            amountItem.bindAmount?()
        }
    }

}

extension SendPresenter: ISendAddressDelegate {

    func onAddressScanClicked() {
        router.scanQrCode(onCodeParse: { [weak self] address in
            self?.onAddressEnter(address: address)
        })
    }

    func onAddressPasteClicked() {
        if let address = interactor.valueFromPasteboard {
            onAddressEnter(address: address)
        }
    }

    func onAddressDeleteClicked() {
        onChange(address: nil)
    }

}

extension SendPresenter: ISendFeeDelegate {

    func onFeePriorityChange(value: Int) {
        userInput.feeRatePriority = FeeRatePriority(rawValue: value) ?? .medium

        let state = interactor.state(forUserInput: userInput)
        let viewItem = factory.viewItem(forState: state, forceRoundDown: false)

        amountItem.hintInfo = viewItem.hintInfo
        amountItem.bindHint?()

        feeItem.feeInfo = viewItem.feeInfo
        feeItem.bind?()

        sendButtonItem.sendButtonEnabled = viewItem.sendButtonEnabled
        sendButtonItem.bind?()
    }

}

extension SendPresenter: ISendButtonDelegate {

    func onSendClicked() {
        let state = interactor.state(forUserInput: userInput)

        guard let viewItem = factory.confirmationViewItem(forState: state, coin: interactor.coin) else {
            return
        }

        view?.showConfirmation(viewItem: viewItem)
    }

}