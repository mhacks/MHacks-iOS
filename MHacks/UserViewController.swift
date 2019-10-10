//
//  UserViewController.swift
//  MHacks
//
//  Created by Russell Ladd on 9/11/16.
//  Copyright © 2016 MHacks. All rights reserved.
//

import UIKit
import PassKit
import CoreImage

final class UserViewController: UIViewController, LoginViewControllerDelegate, PKAddPassesViewControllerDelegate, ScannerViewControllerDelegate {
    
    // MARK: Views
    
    let signInView = UIStackView()
    let ticketView = UIStackView()
    
    let signInTitleLabel = UILabel()
    let signInDescriptionLabel = UILabel()
    let signInButton = UIButton(type: .system)
    
    let ticketBackgroundView = GradientTintView()
    
    let nameTitleLabel = UILabel()
    let nameLabel = UILabel()
    
    let schoolTitleLabel = UILabel()
    let schoolLabel = UILabel()
    
    let scannableCodeView = UIImageView()
    
    let addPassButton = PKAddPassButton(addPassButtonStyle: .black)
    
    let signOutBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Sign Out", comment: "Sign out button title"), style: .plain, target: nil, action: nil)
    let scanBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Scan", comment: "Scan button title"), style: .plain, target: nil, action: nil)
    
    let simhacksButton = UIButton()
    
    // MARK: View life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup sign in view
        
        signInTitleLabel.text = NSLocalizedString("My Ticket", comment: "Sign in title")
        signInTitleLabel.textColor = UIColor.gray
        signInTitleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        
        signInDescriptionLabel.textColor = UIColor.lightGray
        signInDescriptionLabel.text = NSLocalizedString("Tickets are only available to registered hackers.", comment: "Sign in description")
        signInDescriptionLabel.numberOfLines = 0
        signInDescriptionLabel.textAlignment = .center
        
        signInButton.setTitle(NSLocalizedString("Sign In", comment: "Sign in button title"), for: .normal)
        signInButton.addTarget(self, action: #selector(signIn), for: .touchUpInside)
        
        signInView.translatesAutoresizingMaskIntoConstraints = false
        signInView.axis = .vertical
        signInView.spacing = 8.0
        signInView.alignment = .center
        
        signInView.addArrangedSubview(signInTitleLabel)
        signInView.addArrangedSubview(signInDescriptionLabel)
        signInView.addArrangedSubview(signInButton)
        
        // Setup ticket view
        
        signOutBarButtonItem.target = self
        signOutBarButtonItem.action = #selector(signOut)
        
        scanBarButtonItem.target = self
        scanBarButtonItem.action = #selector(scan)
        
        ticketBackgroundView.layer.cornerRadius = 15.0
        
        scannableCodeView.translatesAutoresizingMaskIntoConstraints = false
        scannableCodeView.clipsToBounds = true
        scannableCodeView.layer.cornerRadius = 8.0
        
        nameTitleLabel.text = "HACKER"
        nameTitleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        nameTitleLabel.textColor = UIColor(white: 1.0, alpha: 0.6)
        
        schoolTitleLabel.text = "SCHOOL"
        schoolTitleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        schoolTitleLabel.textColor = UIColor(white: 1.0, alpha: 0.6)
        
        nameLabel.font = UIFont.preferredFont(forTextStyle: .title1)
        nameLabel.textColor = UIColor.white
        nameLabel.numberOfLines = 2
        
        schoolLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        schoolLabel.textColor = UIColor.white
        schoolLabel.numberOfLines = 2
        
        let schoolView = UIStackView(arrangedSubviews: [nameTitleLabel, nameLabel])
        schoolView.axis = .vertical
        schoolView.alignment = .leading
        
        let emailView = UIStackView(arrangedSubviews: [schoolTitleLabel, schoolLabel])
        emailView.axis = .vertical
        emailView.alignment = .leading
        
        let fieldsView = UIStackView(arrangedSubviews: [schoolView, emailView])
        fieldsView.axis = .vertical
        fieldsView.spacing = 20.0
        
        let ticketItemsView = UIStackView(arrangedSubviews: [fieldsView, scannableCodeView])
        ticketItemsView.translatesAutoresizingMaskIntoConstraints = false
        ticketItemsView.axis = .vertical
        ticketItemsView.alignment = .center
        ticketItemsView.spacing = 5.0
        ticketItemsView.distribution = .equalSpacing
        
        simhacksButton.setTitle("SiMHacks", for: .normal)
        simhacksButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .title2)
        simhacksButton.backgroundColor = MHacksColor.lighterBlue
        simhacksButton.layer.cornerRadius = 10
        simhacksButton.addTarget(self, action: #selector(simhacksPressed), for: .touchUpInside)
        
        ticketBackgroundView.addSubview(ticketItemsView)
        
        ticketView.translatesAutoresizingMaskIntoConstraints = false
        ticketView.axis = .vertical
        ticketView.spacing = 15.0
        
        ticketView.addArrangedSubview(ticketBackgroundView)
        ticketView.addArrangedSubview(addPassButton)
        ticketView.addArrangedSubview(simhacksButton)
		
		addPassButton.addTarget(self, action: #selector(addPass(_:)), for: .touchUpInside)
		
        // Setup view
        
        let contentLayoutGuide = UILayoutGuide()
        view.addLayoutGuide(contentLayoutGuide)
        
        view.addSubview(signInView)
        view.addSubview(ticketView)
        
        NSLayoutConstraint.activate([
            contentLayoutGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15.0),
            contentLayoutGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15.0),
            contentLayoutGuide.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor),
            contentLayoutGuide.bottomAnchor.constraint(equalTo: bottomLayoutGuide.topAnchor, constant: -15.0),
            signInView.centerXAnchor.constraint(equalTo: contentLayoutGuide.centerXAnchor),
            signInView.centerYAnchor.constraint(equalTo: contentLayoutGuide.centerYAnchor),
            signInView.widthAnchor.constraint(equalTo: contentLayoutGuide.widthAnchor, multiplier: 0.75),
            ticketView.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
            ticketView.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
            ticketView.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            ticketView.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor, constant: -15.0),
            fieldsView.widthAnchor.constraint(equalTo: ticketItemsView.widthAnchor),
            simhacksButton.widthAnchor.constraint(equalTo: ticketItemsView.widthAnchor),
            simhacksButton.heightAnchor.constraint(equalToConstant: 45),
            ticketItemsView.leadingAnchor.constraint(equalTo: ticketBackgroundView.leadingAnchor, constant: 15.0),
            ticketItemsView.trailingAnchor.constraint(equalTo: ticketBackgroundView.trailingAnchor, constant: -15.0),
            ticketItemsView.topAnchor.constraint(equalTo: ticketBackgroundView.topAnchor, constant: 15.0),
            ticketItemsView.bottomAnchor.constraint(equalTo: ticketBackgroundView.bottomAnchor, constant: -15.0),
            scannableCodeView.widthAnchor.constraint(lessThanOrEqualTo: ticketItemsView.widthAnchor, multiplier: 0.5),
            scannableCodeView.widthAnchor.constraint(equalTo: scannableCodeView.heightAnchor)
        ])
        
        updateViews()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(signInDidChange), name: APIManager.LoginStateChangedNotification, object: nil)
        
        updateViews()
        
        APIManager.shared.updateUserProfile()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: APIManager.LoginStateChangedNotification, object: nil)
    }
    
    // MARK: Update views
    
    func updateViews(animated: Bool = false) {
        
        if case .LoggedIn(let user) = APIManager.shared.userState {
            
            navigationItem.leftBarButtonItem = signOutBarButtonItem
            navigationItem.title = "My Ticket"
            
            signInView.alpha = 0.0
            ticketView.alpha = 1.0
            
            nameLabel.text = user.name
            schoolLabel.text = user.university ?? "Unknown"
            
            let userIDData = user.userID.data(using: .isoLatin1)!
            
            let qrCodeGenerator = CIFilter(name: "CIQRCodeGenerator")!
            qrCodeGenerator.setValue(userIDData, forKey: "inputMessage")
            qrCodeGenerator.setValue("M", forKey: "inputCorrectionLevel")
            
            let scaleFilter = CIFilter(name: "CIAffineTransform")!
            scaleFilter.setValue(qrCodeGenerator.outputImage, forKey: "inputImage")
            scaleFilter.setValue(NSValue(cgAffineTransform: CGAffineTransform(scaleX: 20.0, y: 20.0)), forKey: "inputTransform")
            
            scannableCodeView.image = UIImage(ciImage: scaleFilter.outputImage!)
            
        } else {
            
            navigationItem.setLeftBarButton(nil, animated: animated)
            navigationItem.title = nil
            
            UIView.animateKeyframes(withDuration: animated ? 1.0 : 0.0, delay: 0.0, options: [], animations: {
                
                UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.4, animations: {
                    self.ticketView.alpha = 0.0
                })
                
                UIView.addKeyframe(withRelativeStartTime: 0.6, relativeDuration: 0.4, animations: {
                    self.signInView.alpha = 1.0
                })
                
            }, completion: nil)
        }
        
        navigationItem.setRightBarButton(APIManager.shared.canScanUserCode ? scanBarButtonItem : nil, animated: animated)
    }
    
    // MARK: Actions
    
    @objc func signIn() {
        
        let loginViewController = LoginViewController()
        loginViewController.delegate = self
        
        let loginNavigationController = UINavigationController(rootViewController: loginViewController)
        
        present(loginNavigationController, animated: true, completion: nil)
    }
    
    @objc func signOut() {
        APIManager.shared.logout()
    }
    
    @objc func scan() {
        
        let scannerViewController = ScannerViewController(questType: nil)
        scannerViewController.delegate = self
        
        let scannerNavigationController = UINavigationController(rootViewController: scannerViewController)
        scannerNavigationController.isToolbarHidden = false
        
        present(scannerNavigationController, animated: true, completion: nil)
    }
    
    @objc func signInDidChange() {
        
        DispatchQueue.main.async {
            
            // Not a good way to determine the animated flag
            // Okay solution in this isolated case
            self.updateViews(animated: !APIManager.shared.loggedIn)
        }
    }
	
	@objc func addPass(_ sender: PKAddPassButton) {
        
        view.isUserInteractionEnabled = false
        
		APIManager.shared.fetchPass { pass in
            
            DispatchQueue.main.async {
                self.view.isUserInteractionEnabled = true
            }
            
			guard let pass = pass else {
				// Request failed
				return
			}
            
			let passesViewController = PKAddPassesViewController(pass: pass)
            passesViewController!.delegate = self
            self.present(passesViewController!, animated: true, completion: nil)
		}
	}
    
    func makeAlertController(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let alertAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(alertAction)
        self.present(alert, animated: true, completion: nil)
    }
    
    @objc func simhacksPressed() {
        let simhacksNav = UINavigationController(rootViewController: SiMHacksViewController())
        
        let date = Date()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm"
        let hackingStarts = dateFormatter.date(from: "2019/10/11 23:00")

        // TODO: change this to call /v1/configuration endpoint, waiting on Carson
        #if DEBUG
            self.present(simhacksNav, animated: true, completion: nil)
        #else
            // Check to see if SiMHacks can be released yet
            if date >= hackingStarts! {
                print("Can start playing!")
                self.present(simhacksNav, animated: true, completion: nil)
            } else {
                self.makeAlertController(title: "Can't access yet", message: "SiMHacks will open at 7pm EST, October 11th.")
            }
        #endif
    }
	
    // MARK: Login view controller delegate
    
    func loginViewControllerDidCancel(loginViewController: LoginViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    func loginViewControllerDidLogin(loginViewController: LoginViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: Add passed view controller delegate
	
	func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
		dismiss(animated: true, completion: nil)
	}
    
    // MARK: Scanner view controller delegate
    
    func scannerViewControllerDidFinish(scannerViewController: ScannerViewController) {
        dismiss(animated: true, completion: nil)
    }
}
