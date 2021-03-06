//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import UIKit
import Social
import WireShareEngine
import Cartography
import MobileCoreServices
import ZMCDataModel
import WireExtensionComponents
import Classy


var globSharingSession : SharingSession? = nil

class ShareViewController: SLComposeServiceViewController {
    
    var conversationItem : SLComposeSheetConfigurationItem?
    var selectedConversation : Conversation?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let rightButtonBarItem = navigationController?.navigationBar.items?.first?.rightBarButtonItem {
            rightButtonBarItem.action = #selector(appendPostTapped)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    override func presentationAnimationDidFinish() {
        let bundle = Bundle.main
        
        if let applicationGroupIdentifier = bundle.infoDictionary?["ApplicationGroupIdentifier"] as? String, let hostBundleIdentifier = bundle.infoDictionary?["HostBundleIdentifier"] as? String, globSharingSession == nil {
            
                globSharingSession = try? SharingSession(applicationGroupIdentifier: applicationGroupIdentifier, hostBundleIdentifier: hostBundleIdentifier)
            }
        
    
        guard let sharingSession = globSharingSession, sharingSession.canShare else {
            presentNotSignedInMessage()
            return
        }
    }
    
    func appendPostTapped() {
        sendShareable { [weak self] (messages) in
            self?.presentSendingProgress(forMessages: messages)
        }
    }
    
    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return globSharingSession != nil && selectedConversation != nil
    }

    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
        
        if let sharingSession = globSharingSession, let conversation = selectedConversation {
            sharingSession.enqueue(changes: { 
                _ = conversation.appendTextMessage(self.contentText)
            })
        }
    }
    
    
    func sendShareable(sentCompletionHandler: @escaping ([Sendable]) -> Void) {
        
        var messages : [Sendable] = []
        
        guard let sharingSession = globSharingSession,
              let conversation = selectedConversation else {
            sentCompletionHandler(messages)
            return
        }
        
        let sendingGroup = DispatchGroup()
        
        if !self.contentText.isEmpty {
            sendingGroup.enter()
            sharingSession.enqueue {
                if let message = conversation.appendTextMessage(self.contentText) {
                    messages.append(message)
                }
                sendingGroup.leave()
            }
        }
        
        extensionContext?.inputItems.forEach { inputItem in
        
            if let extensionItem = inputItem as? NSExtensionItem,
               let attachments = extensionItem.attachments as? [NSItemProvider] {
        
                let hasImageAttachment = !attachments.filter { $0.hasItemConformingToTypeIdentifier(kUTTypeImage as String) }.isEmpty
                for attachment in attachments {
                    
                    if attachment.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                        
                        sendingGroup.enter()
                        let preferredSize = NSValue.init(cgSize: CGSize(width: 1024, height: 1024))
                        attachment.loadItem(forTypeIdentifier: kUTTypeJPEG as String, options: [NSItemProviderPreferredImageSizeKey : preferredSize], imageCompletionHandler: { [weak self] (image, error) in
                            guard let image = image,
                                  let sharingSession = globSharingSession,
                                  let conversation = self?.selectedConversation,
                                  let imageData = UIImageJPEGRepresentation(image, 0.9),
                                  error == nil else {
                                    
                                sendingGroup.leave()
                                return
                            }
                            
                            DispatchQueue.main.async {
                                sharingSession.enqueue {
                                    if let message = conversation.appendImage(imageData) {
                                        messages.append(message)
                                    }
                                    sendingGroup.leave()
                                }
                            }
                        })
                    }
                    else if !hasImageAttachment && attachment.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {

                        sendingGroup.enter()
                        attachment.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil, urlCompletionHandler: { [weak self] (url, error) in
                            
                            guard let url = url,
                                  let sharingSession = globSharingSession,
                                  let conversation = self?.selectedConversation,
                                  error != nil else {
                                    
                                sendingGroup.leave()
                                return
                            }
                            
                            DispatchQueue.main.async {
                                sharingSession.enqueue {
                                    if let message = conversation.appendTextMessage(url.absoluteString) {
                                        messages.append(message)
                                    }
                                    sendingGroup.leave()
                                }
                            }
                        })
                    }
                    else if attachment.hasItemConformingToTypeIdentifier(kUTTypeData as String) {
                        sendingGroup.enter()
                        
                        attachment.loadItem(forTypeIdentifier: kUTTypeData as String, options: [:], dataCompletionHandler: { [weak self](data, error) in
                            guard let `self` = self,
                                  let data = data,
                                  let UTIString = attachment.registeredTypeIdentifiers.first as? String,
                                  error == nil else {
                                    
                                    sendingGroup.leave()
                                    return
                            }
                            
                            self.process(data:data, UTIString: UTIString) { url, error in
                                guard let url = url,
                                    let sharingSession = globSharingSession,
                                    let conversation = self.selectedConversation,
                                    error == nil else {
                                        
                                        sendingGroup.leave()
                                        return
                                }
                                DispatchQueue.main.async {
                                    FileMetaDataGenerator.metadataForFileAtURL(url, UTI: url.UTI()) { metadata -> Void in
                                        sharingSession.enqueue {
                                            if let message = conversation.appendFile(metadata) {
                                                messages.append(message)
                                            }
                                            sendingGroup.leave()
                                        }
                                    }
                                }
                            }
                            
                        }) //END LOAD ITEM
                        
                    } //ENDIF
                }
            }
        }
        
        sendingGroup.notify(queue: .main) {
            sentCompletionHandler(messages)
        }
    }
    
    func process(data: Data, UTIString UTI: String, completionHandler: @escaping (URL?, Error?)->Void ) {
        let fileExtension = UTTypeCopyPreferredTagWithClass(UTI as CFString, kUTTagClassFilenameExtension as CFString)?.takeRetainedValue() as! String
        let tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
        if FileManager.default.fileExists(atPath: tempFileURL.absoluteString) {
            try! FileManager.default.removeItem(at: tempFileURL)
        }
        do {
            try data.write(to: tempFileURL)
        } catch {
            completionHandler(nil, NSError())
            return
        }
        
        
        if UTTypeConformsTo(UTI as CFString, kUTTypeMovie) {
            AVAsset.wr_convertVideo(at: tempFileURL) { (url, _, error) in
                completionHandler(url, error)
            }
        } else {
            completionHandler(tempFileURL, nil)
        }
    }
    
    override func didReceiveMemoryWarning() {
        print("Y U USE SO MCUH MEMORI")
    }

    override func configurationItems() -> [Any]! {
        let conversationItem = SLComposeSheetConfigurationItem()!
        self.conversationItem = conversationItem
        
        conversationItem.title = "Share to:"
        conversationItem.value = "None"
        conversationItem.tapHandler = { [weak self] in
             self?.selectConversation()
        }
        
        return [conversationItem]
    }
    
    func presentSendingProgress(forMessages messages: [Sendable]) {
        let progressViewController = SendingProgressViewController(messages: messages)
        
        progressViewController.cancelHandler = { [weak self] in
            self?.cancel()
        }
        
        progressViewController.sentHandler = { [weak self] in
            self?.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
        }
        
        pushConfigurationViewController(progressViewController)
    }
    
    func presentNotSignedInMessage() {
        let notSignedInViewController = NotSignedInViewController()
        
        notSignedInViewController.closeHandler = { [weak self] in
            self?.cancel()
        }
        
        pushConfigurationViewController(notSignedInViewController)
    }
    
    func selectConversation() {
        guard let sharingSession = globSharingSession else { return }

        let conversationSelectionViewController = ConversationSelectionViewController(conversations: sharingSession.writeableNonArchivedConversations)
        
        conversationSelectionViewController.selectionHandler = { [weak self] conversation in
            self?.conversationItem?.value = conversation.name
            self?.selectedConversation = conversation
            self?.popConfigurationViewController()
            self?.validateContent()
        }
        
        pushConfigurationViewController(conversationSelectionViewController)
    }
    
}

class SendingProgressViewController : UIViewController, SendableObserver {
    
    var sentHandler : (() -> Void)?
    var cancelHandler : (() -> Void)?
    
    private var progressLabel = UILabel()
    private var observers : [(Sendable, SendableObserverToken)] = []
    
    var totalProgress : Float {
        var totalProgress : Float = 0.0
        
        observers.forEach { (message, _) in
            if message.deliveryState == .sent || message.deliveryState == .delivered {
                totalProgress = totalProgress + 1.0 / Float(observers.count)
            } else {
                let messageProgress = (message.deliveryProgress ?? 0)
                totalProgress = totalProgress +  messageProgress / Float(observers.count)
            }
        }
        
        return totalProgress
    }
    
    var isAllMessagesDelivered : Bool {
        return observers.reduce(true) { (result, observer) -> Bool in
            return result && (observer.0.deliveryState == .sent || observer.0.deliveryState == .delivered)
        }
    }
    
    init(messages: [Sendable]) {
        super.init(nibName: nil, bundle: nil)
        
        messages.forEach {message in
            observers.append((message, (message.registerObserverToken(self))))
        }
    }
    
    deinit {
        observers.forEach { (message, token) in
            message.remove(token)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.hidesBackButton = true
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(onCancelTapped))
        
        progressLabel.text = "0%";
        progressLabel.textAlignment = .center
        progressLabel.font = UIFont.systemFont(ofSize: 32)
        
        view.addSubview(progressLabel)
        
        constrain(view, progressLabel) { container, progressLabel in
            progressLabel.edges == container.edgesWithinMargins
        }
    }
    
    func onCancelTapped() {
        observers.filter {
            $0.0.deliveryState != .sent && $0.0.deliveryState != .delivered
        }.forEach {
            $0.0.cancel()
        }
        cancelHandler?()
    }
    
    func onDeliveryChanged() {
        progressLabel.text = "\(Int(self.totalProgress * 100))%"
        
        if self.isAllMessagesDelivered {
            sentHandler?()
        }
    }
}

class NotSignedInViewController : UIViewController {
    
    var closeHandler : (() -> Void)?
    
    let messageLabel = UILabel()
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.hidesBackButton = true
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(onCloseTapped))
        
        messageLabel.text = "You need to sign into Wire before you can share anything";
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        
        view.addSubview(messageLabel)
        
        constrain(view, messageLabel) { container, messageLabel in
            messageLabel.edges == container.edgesWithinMargins
        }
    }
    
    func onCloseTapped() {
        closeHandler?()
    }
}

class ConversationSelectionViewController : UITableViewController {
    
    var conversations : [Conversation]
    
    var selectionHandler : ((_ conversation: Conversation) -> Void)?
    
    init(conversations: [Conversation]) {
        self.conversations = conversations
        
        super.init(style: .plain)
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ConversationCell")
        preferredContentSize = UIScreen.main.bounds.size
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .clear
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let conversation = conversations[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "ConversationCell", for: indexPath)
        
        cell.textLabel?.text = conversation.name
        cell.backgroundColor = .clear
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let selectionHandler =  selectionHandler {
            selectionHandler(conversations[indexPath.row])
        }
    }
    
}
