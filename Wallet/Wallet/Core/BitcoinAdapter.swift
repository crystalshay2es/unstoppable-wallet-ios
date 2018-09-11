import Foundation
import WalletKit
import RealmSwift
import RxSwift

class BitcoinAdapter {
    private let walletKit: WalletKit
    private var unspentOutputsNotificationToken: NotificationToken?
    private var transactionsNotificationToken: NotificationToken?
    private let transactionCompletionThreshold = 6

    let wordsHash: String
    let coin: Coin
    let balanceSubject = PublishSubject<Double>()
    let latestBlockHeightSubject = PublishSubject<Void>()
    let transactionRecordsSubject = PublishSubject<Void>()

    var balance: Double = 0 {
        didSet {
            balanceSubject.onNext(balance)
        }
    }

    init(words: [String], networkType: WalletKit.NetworkType) {
        wordsHash = words.joined()

        switch networkType {
        case .bitcoinMainNet: coin = Bitcoin()
        case .bitcoinTestNet: coin = Bitcoin(prefix: "t")
        case .bitcoinRegTest: coin = Bitcoin(prefix: "r")
        case .bitcoinCashMainNet: coin = BitcoinCash()
        case .bitcoinCashTestNet: coin = BitcoinCash(prefix: "t")
        }

        let realmFileName = "\(wordsHash)-\(coin.code).realm"

        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let configuration = Realm.Configuration(fileURL: documentsUrl?.appendingPathComponent(realmFileName))

        walletKit = WalletKit(withWords: words, realmConfiguration: configuration, networkType: networkType)

        unspentOutputsNotificationToken = walletKit.unspentOutputsRealmResults.observe { [weak self] _ in
            self?.updateBalance()
        }

        transactionsNotificationToken = walletKit.transactionsRealmResults.observe { [weak self] _ in
            self?.transactionRecordsSubject.onNext(())
        }
    }

    deinit {
        unspentOutputsNotificationToken?.invalidate()
        transactionsNotificationToken?.invalidate()
    }

    private func updateBalance() {
        var satoshiBalance = 0

        for output in walletKit.unspentOutputsRealmResults {
            satoshiBalance += output.value
        }

        balance = Double(satoshiBalance) / 100000000
    }

    private func transactionRecord(fromTransaction transaction: Transaction) -> TransactionRecord {
        var totalMineInput: Int = 0
        var totalMineOutput: Int = 0
        var fromAddresses = [TransactionAddress]()
        var toAddresses = [TransactionAddress]()

        for input in transaction.inputs {
            if let previousOutput = input.previousOutput {
                if previousOutput.publicKey != nil {
                    totalMineInput += previousOutput.value
                }
            }
            let mine = input.previousOutput?.publicKey != nil
            if let address = input.address {
                fromAddresses.append(TransactionAddress(address: address, mine: mine))
            }
        }

        for output in transaction.outputs {
            var mine = false
            if output.publicKey != nil {
                totalMineOutput += output.value
                mine = true
            }
            if let address = output.address {
                toAddresses.append(TransactionAddress(address: address, mine: mine))
            }
        }

        let amount = totalMineOutput - totalMineInput
        let status: TransactionStatus

        if let block = transaction.block {
            let confirmations = walletKit.latestBlockHeight - block.height + 1
            if confirmations >= transactionCompletionThreshold {
                status = .completed
            } else {
                status = .verifying(progress: Double(confirmations) / Double(transactionCompletionThreshold))
            }
        } else {
            status = .processing
        }

        return TransactionRecord(
                transactionHash: transaction.reversedHashHex,
                from: fromAddresses,
                to: toAddresses,
                amount: Double(amount) / 100000000,
                status: status,
                timestamp: transaction.block?.header?.timestamp
        )
    }

}

extension BitcoinAdapter: IAdapter {

    var id: String {
        return "\(wordsHash)-\(coin.code)"
    }

    var latestBlockHeight: Int {
        return walletKit.latestBlockHeight
    }

    var transactionRecords: [TransactionRecord] {
        var records = [TransactionRecord]()

        for transaction in walletKit.transactionsRealmResults {
            records.append(transactionRecord(fromTransaction: transaction))
        }

        return records
    }

    func showInfo() {
        walletKit.showRealmInfo()
    }

    func start() throws {
        try walletKit.start()
    }

    func clear() throws {
        try walletKit.clear()
    }

    func send(to address: String, value: Int) throws {
        try walletKit.send(to: address, value: value)
    }

    func fee(for value: Int, senderPay: Bool) throws -> Int {
        return try walletKit.fee(for: value, senderPay: senderPay)
    }

    func validate(address: String) -> Bool {
        return true
    }

    var receiveAddress: String {
        return walletKit.receiveAddress
    }

    var progressSubject: BehaviorSubject<Double> {
        return walletKit.progressSubject
    }

}
