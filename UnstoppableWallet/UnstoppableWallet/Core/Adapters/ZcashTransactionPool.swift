import Foundation
import ZcashLightClientKit
import RxSwift

class ZcashTransactionPool {
    private var confirmedTransactions = Set<ZcashTransactionWrapper>()
    private var pendingTransactions = Set<ZcashTransactionWrapper>()
    private let synchronizer: SDKSynchronizer
    private let receiveAddress: SaplingAddress

    init(synchronizer: SDKSynchronizer, receiveAddress: SaplingAddress) {
        self.synchronizer = synchronizer
        self.receiveAddress = receiveAddress
    }

    private func transactions(filter: TransactionTypeFilter) -> [ZcashTransactionWrapper] {
        var confirmedTransactions = confirmedTransactions
        var pendingTransactions = pendingTransactions
        switch filter {
        case .all: ()
        case .incoming:
            confirmedTransactions = confirmedTransactions.filter { !$0.isSentTransaction }
            pendingTransactions = pendingTransactions.filter { !$0.isSentTransaction }
        case .outgoing:
            confirmedTransactions = confirmedTransactions.filter { $0.isSentTransaction }
            pendingTransactions = pendingTransactions.filter { !$0.isSentTransaction }
        default:
            confirmedTransactions = []
            pendingTransactions = []
        }

        return Array(confirmedTransactions.union(pendingTransactions)).sorted()
    }

    private func zcashTransactions(_ transactions: [PendingTransactionEntity]) -> [ZcashTransactionWrapper] {
        transactions.compactMap { ZcashTransactionWrapper(pendingTransaction: $0) }
    }

    private func zcashTransactions(_ transactions: [ZcashTransaction.Overview]) -> [ZcashTransactionWrapper] {
        transactions.compactMap { ZcashTransactionWrapper(confirmedTransaction: $0) }
    }

    @discardableResult private func sync(own: inout Set<ZcashTransactionWrapper>, incoming: [ZcashTransactionWrapper]) -> [ZcashTransactionWrapper] {
        var newTxs = [ZcashTransactionWrapper]()
        incoming.forEach { transaction in
            if own.insert(transaction).inserted {
                newTxs.append(transaction)
            }
        }
        return newTxs
    }

    func store(confirmedTransactions: [ZcashTransaction.Overview], pendingTransactions: [PendingTransactionEntity]) {
        self.pendingTransactions = Set(zcashTransactions(pendingTransactions))
        self.confirmedTransactions = Set(zcashTransactions(confirmedTransactions))
    }

    func sync(transactions: [PendingTransactionEntity]) -> [ZcashTransactionWrapper] {
        sync(own: &pendingTransactions, incoming: zcashTransactions(transactions))
    }

    func sync(transactions: [ZcashTransaction.Overview]) -> [ZcashTransactionWrapper] {
        sync(own: &confirmedTransactions, incoming: zcashTransactions(transactions))
    }

    func transaction(by hash: String) -> ZcashTransactionWrapper? {
        transactions(filter: .all).first { $0.transactionHash == hash }
    }

}

extension ZcashTransactionPool {

    func transactionsSingle(from: TransactionRecord?, filter: TransactionTypeFilter, limit: Int) -> Single<[ZcashTransactionWrapper]> {
        let transactions = transactions(filter: filter)

        guard let transaction = from else {
            return Single.just(Array(transactions.prefix(limit)))
        }

        if let index = transactions.firstIndex(where: { $0.transactionHash == transaction.transactionHash }) {
            return Single.just((Array(transactions.suffix(from: index + 1).prefix(limit))))
        }
        return Single.just([])
    }

}

//extension PendingTransactionEntity {
//
//    func transactionEntity(defaultFee: Zatoshi) -> ZcashTransaction.Overview {
//        ZcashTransaction.Overview(
//                blockTime: createTime,
//                expiryHeight: expiryHeight,
//                fee: fee,
//                id: id ?? -1,
//                index: nil,
//                isWalletInternal: false,
//                hasChange: false,
//                memoCount: 0,
//                minedHeight: minedHeight,
//                raw: raw,
//                rawID: rawTransactionId ?? Data(),
//                receivedNoteCount: 0,
//                sentNoteCount: 0,
//                value: value
//        )
//    }
//
//}