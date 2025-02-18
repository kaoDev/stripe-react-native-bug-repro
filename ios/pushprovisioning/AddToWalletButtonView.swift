//
//  AddToWalletButtonView.swift
//  stripe-react-native
//
//  Created by Charles Cruzan on 3/28/22.
//

import Foundation
import Stripe

@objc(AddToWalletButtonView)
class AddToWalletButtonView: UIView {
    var pushProvisioningContext: STPPushProvisioningContext? = nil
    var addToWalletButton: PKAddPassButton? = nil

    @objc var testEnv: Bool = false
    @objc var iOSButtonStyle: NSString?
    @objc var cardHolderName: NSString?
    @objc var cardDescription: NSString?
    @objc var cardLastFour: NSString?
    @objc var cardBrand: NSString?
    @objc var ephemeralKey: NSDictionary?
    @objc var onCompleteAction: RCTDirectEventBlock?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        if let addToWalletButton = self.addToWalletButton {
            addToWalletButton.frame = self.bounds
        }
    }

    func canAddPaymentPass() -> Bool {
        return self.testEnv ? STPFakeAddPaymentPassViewController.canAddPaymentPass() : PKAddPaymentPassViewController.canAddPaymentPass()
    }

    override func didSetProps(_ changedProps: [String]!) {
        if let addToWalletButton = addToWalletButton {
            addToWalletButton.removeFromSuperview()
        }

        let style = Mappers.mapToPKAddPassButtonStyle(style: iOSButtonStyle as String?)

        self.addToWalletButton = PKAddPassButton.init(addPassButtonStyle: style)

        if let addToWalletButton = self.addToWalletButton {
            addToWalletButton.addTarget(self, action: #selector(beginPushProvisioning), for: .touchUpInside)
            self.addSubview(addToWalletButton)
        }
    }

    @objc func beginPushProvisioning() {
        if (!canAddPaymentPass()) {
            onCompleteAction!(
                Errors.createError(
                    ErrorType.Failed,
                    "This app cannot add cards to Apple Pay. For information on requesting the necessary entitlement, see the Card Issuers section at developer.apple.com/apple-pay/."
                ) as? [AnyHashable : Any]
            )
            return
        }
        
        guard let cardHolderName = cardHolderName as String? else {
            onCompleteAction!(
                Errors.createError(
                    ErrorType.Failed,
                    "Missing parameters. `cardHolderName` must be supplied in the props to <AddToWalletButton />"
                ) as? [AnyHashable : Any]
            )
            return
        }
        
        if (cardHolderName.isEmpty) {
            onCompleteAction!(
                Errors.createError(
                    ErrorType.Failed,
                    "`cardHolderName` is required, but the passed string was empty"
                ) as? [AnyHashable : Any]
            )
            return
        }

        let config = STPPushProvisioningContext.requestConfiguration(
            withName: cardHolderName,
            description: cardDescription as String?,
            last4: cardLastFour as String?,
            brand: Mappers.mapToCardBrand(cardBrand as String?)
        )
        
        // We can use STPFakeAddPaymentPassViewController ONLY IN TEST MODE. If STPFakeAddPaymentPassViewController is
        // used with a live mode card, the flow will fail and show a 'Signing certificate was invalid' error.
        let controller = {
            return self.testEnv ? STPFakeAddPaymentPassViewController(requestConfiguration: config, delegate: self) : PKAddPaymentPassViewController(requestConfiguration: config, delegate: self)
        }()
        
        let vc = findViewControllerPresenter(from: UIApplication.shared.delegate?.window??.rootViewController ?? UIViewController())
        vc.present(controller!, animated: true, completion: nil)
    }
}


extension AddToWalletButtonView: PKAddPaymentPassViewControllerDelegate {
    func addPaymentPassViewController(_ controller: PKAddPaymentPassViewController, generateRequestWithCertificateChain certificates: [Data], nonce: Data, nonceSignature: Data, completionHandler handler: @escaping (PKAddPaymentPassRequest) -> Void) {
        self.pushProvisioningContext = STPPushProvisioningContext(keyProvider: self)

        self.pushProvisioningContext?.addPaymentPassViewController(controller, generateRequestWithCertificateChain: certificates, nonce: nonce, nonceSignature: nonceSignature, completionHandler: handler);
    }

    func addPaymentPassViewController(_ controller: PKAddPaymentPassViewController, didFinishAdding pass: PKPaymentPass?, error: Error?) {
        if let error = error as NSError? {
            onCompleteAction!(
                Errors.createError(
                    error.code == PKAddPaymentPassError.userCancelled.rawValue ? ErrorType.Canceled : ErrorType.Failed,
                    error as NSError?
                ) as? [AnyHashable : Any]
            )
        } else {
            onCompleteAction!([
                "error": NSNull(),
            ] as [AnyHashable : Any])
        }
        controller.dismiss(animated: true, completion: nil)
    }
}


extension AddToWalletButtonView: STPIssuingCardEphemeralKeyProvider {
    func createIssuingCardKey(withAPIVersion apiVersion: String, completion: @escaping STPJSONResponseCompletionBlock) {
        if let ephemeralKey = self.ephemeralKey as? [AnyHashable : Any] {
            completion(ephemeralKey, nil)
        } else {
            onCompleteAction!(
                Errors.createError(
                    ErrorType.Failed,
                    "Missing parameters. `ephemeralKey` must be supplied in the props to <AddToWalletButton />"
                ) as? [AnyHashable : Any]
            )
            completion(nil, nil)
        }
    }
}
