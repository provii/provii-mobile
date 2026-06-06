// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI

/// Open source licence viewer presenting each dependency in an expandable card with
/// the full licence text. Supports breadcrumb navigation, Dynamic Type scaling, and
/// VoiceOver traits on every interactive element.
struct LicensesView: View {
    @EnvironmentObject var accessibilityManager: AccessibilityManager
    @Environment(\.dismiss) private var dismiss
    @State private var expandedLicenses: Set<String> = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: accessibilityManager.settings.increaseTouchTargets ? 20 : 16) {
                    // Breadcrumb Navigation
                    BreadcrumbView(path: [
                        NSLocalizedString("breadcrumb.home", comment: "Home"),
                        NSLocalizedString("breadcrumb.settings", comment: "Settings"),
                        NSLocalizedString("breadcrumb.licenses", comment: "Licences")
                    ])
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Header Section
                    headerSection

                    // iOS Dependencies Section
                    sectionHeader(
                        title: NSLocalizedString("licenses_ios_dependencies", comment: "iOS Dependencies"),
                        icon: "apple.logo"
                    )

                    // YubiKit
                    licenseCard(
                        library: LicenseInfo(
                            name: "YubiKit",
                            version: "4.7.0",
                            licenseType: NSLocalizedString("licenses_apache_2", comment: "Apache License 2.0"),
                            copyright: "Copyright Yubico",
                            url: "https://github.com/Yubico/yubikit-ios",
                            fullLicenseText: apacheLicenseText
                        )
                    )

                    // SwiftUI / Foundation Section
                    sectionHeader(
                        title: NSLocalizedString("licenses_apple_frameworks", comment: "Apple Frameworks"),
                        icon: "swift"
                    )

                    licenseCard(
                        library: LicenseInfo(
                            name: "SwiftUI",
                            version: "iOS 16+",
                            licenseType: NSLocalizedString("licenses_apple_proprietary", comment: "Apple Software License"),
                            copyright: "Copyright © Apple Inc.",
                            url: "https://www.apple.com/legal/sla/",
                            fullLicenseText: NSLocalizedString("licenses_apple_framework_notice", comment: "SwiftUI and Foundation are Apple frameworks provided under the Apple Software License Agreement. These frameworks are part of the iOS SDK.")
                        )
                    )

                    licenseCard(
                        library: LicenseInfo(
                            name: "Foundation",
                            version: "iOS 16+",
                            licenseType: NSLocalizedString("licenses_apple_proprietary", comment: "Apple Software License"),
                            copyright: "Copyright © Apple Inc.",
                            url: "https://www.apple.com/legal/sla/",
                            fullLicenseText: NSLocalizedString("licenses_apple_framework_notice", comment: "SwiftUI and Foundation are Apple frameworks provided under the Apple Software License Agreement. These frameworks are part of the iOS SDK.")
                        )
                    )

                    // Additional iOS Frameworks
                    licenseCard(
                        library: LicenseInfo(
                            name: "Combine",
                            version: "iOS 16+",
                            licenseType: NSLocalizedString("licenses_apple_proprietary", comment: "Apple Software License"),
                            copyright: "Copyright © Apple Inc.",
                            url: "https://www.apple.com/legal/sla/",
                            fullLicenseText: NSLocalizedString("licenses_apple_framework_notice", comment: "SwiftUI and Foundation are Apple frameworks provided under the Apple Software License Agreement. These frameworks are part of the iOS SDK.")
                        )
                    )

                    licenseCard(
                        library: LicenseInfo(
                            name: "CryptoKit",
                            version: "iOS 16+",
                            licenseType: NSLocalizedString("licenses_apple_proprietary", comment: "Apple Software License"),
                            copyright: "Copyright © Apple Inc.",
                            url: "https://www.apple.com/legal/sla/",
                            fullLicenseText: NSLocalizedString("licenses_apple_framework_notice", comment: "SwiftUI and Foundation are Apple frameworks provided under the Apple Software License Agreement. These frameworks are part of the iOS SDK.")
                        )
                    )

                    // Wallet SDK (Rust Dependencies) Section
                    sectionHeader(
                        title: NSLocalizedString("licenses_wallet_sdk", comment: "Wallet SDK (Rust)"),
                        icon: "cpu"
                    )

                    licenseCard(
                        library: LicenseInfo(
                            name: "ed25519-dalek, curve25519-dalek, subtle",
                            version: "2.2.0 / 4.1.3 / 2.6.1",
                            licenseType: "BSD-3-Clause",
                            copyright: "Copyright (c) the respective authors",
                            url: "https://github.com/dalek-cryptography",
                            fullLicenseText: bsd3LicenseText
                        )
                    )

                    licenseCard(
                        library: LicenseInfo(
                            name: "UniFFI",
                            version: "0.29.5",
                            licenseType: "MPL-2.0",
                            copyright: "Copyright (c) Mozilla Foundation",
                            url: "https://github.com/mozilla/uniffi-rs",
                            fullLicenseText: mpl2SummaryText
                        )
                    )

                    licenseCard(
                        library: LicenseInfo(
                            name: "rustls, aws-lc-rs, webpki-roots",
                            version: "0.23.36 / 1.15.2 / 0.26.11",
                            licenseType: "Apache-2.0 / ISC / OpenSSL",
                            copyright: "Copyright (c) the respective authors",
                            url: "https://github.com/rustls/rustls",
                            fullLicenseText: "rustls is licensed under Apache-2.0 OR ISC OR MIT. aws-lc-rs and aws-lc-sys are licensed under ISC AND "
                                + "(Apache-2.0 OR ISC) AND OpenSSL. webpki-roots is licensed under CDLA-Permissive-2.0 (Community Data Licence Agreement). "
                                + "All are permissive licences that allow commercial use and binary distribution."
                        )
                    )

                    licenseCard(
                        library: LicenseInfo(
                            name: "ICU4X Unicode Libraries",
                            version: "2.1.x",
                            licenseType: "Unicode-3.0",
                            copyright: "Copyright \u{00A9} Unicode, Inc.",
                            url: "https://github.com/unicode-org/icu4x",
                            fullLicenseText: "The ICU4X crates (icu_collections, icu_locale_core, icu_normalizer, icu_properties, icu_provider, and related crates) "
                                + "are licensed under the Unicode Licence Agreement (Unicode-3.0). Permission is hereby granted, free of charge, to any person "
                                + "obtaining a copy of data files and any associated documentation, to deal in the data files without restriction."
                        )
                    )

                    licenseCard(
                        library: LicenseInfo(
                            name: "Rust Core Libraries (~400 crates)",
                            version: "Various",
                            licenseType: "MIT OR Apache-2.0",
                            copyright: "Copyright (c) the respective authors",
                            url: "",
                            fullLicenseText: "Approximately 400 Rust crates are dual-licensed under MIT OR Apache-2.0, including: tokio (async runtime), serde "
                                + "(serialisation), hyper (HTTP), blake2 and sha2 (hashing), rand (randomness), chrono (date/time), anyhow (error handling), "
                                + "zeroize (memory clearing), quinn (QUIC transport), postcard (compact serialisation), hex, base64 (encoding), url, uuid, "
                                + "and many others. The full list is available in THIRD_PARTY_LICENSES.md."
                        )
                    )

                    // Font Licences
                    sectionHeader(
                        title: NSLocalizedString("licenses_fonts", comment: "Fonts"),
                        icon: "textformat"
                    )

                    if accessibilityManager.settings.useDyslexiaFont {
                        licenseCard(
                            library: LicenseInfo(
                                name: "OpenDyslexic",
                                version: "2.0",
                                licenseType: NSLocalizedString("licenses_ofl", comment: "SIL Open Font License"),
                                copyright: "Copyright © Abelardo Gonzalez",
                                url: "https://opendyslexic.org/",
                                fullLicenseText: openFontLicenseText
                            )
                        )
                    }

                    // Footer with additional info
                    footerSection
                }
                .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
            }
            .background(AccessibleColors.background)
            .navigationTitle(NSLocalizedString("licenses_title", comment: "Open Source Licences"))
            .navigationBarTitleDisplayMode(.large)
            // WCAG 2.2 AAA: 2.4.8 Location - breadcrumb navigation
            .setNavigationPath(["Home", "Settings", "Licences"])
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("done", comment: "Done")) {
                        dismiss()
                    }
                    .foregroundColor(AccessibleColors.primary)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(accessibilityManager.settings.useExtraLargeText ? AccessibleTypography.title2 : AccessibleTypography.title3)
                    .foregroundColor(AccessibleColors.primary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("licenses_title", comment: "Open Source Licences"))
                        .font(AccessibleTypography.headline)
                        .foregroundColor(AccessibleColors.text)
                        .accessibilityAddTraits(.isHeader)

                    Text(NSLocalizedString("licenses_description", comment: "This app uses the following open source software"))
                        .font(AccessibleTypography.caption)
                        .foregroundColor(AccessibleColors.secondaryText)
                }
            }

            if accessibilityManager.settings.verboseDescriptions {
                Text(NSLocalizedString("licenses_verbose_description", comment: "Open source licences detail the terms under which software libraries can be used, modified, and distributed. Provii Wallet is built on these excellent projects."))
                    .font(AccessibleTypography.caption)
                    .foregroundColor(AccessibleColors.secondaryText)
                    .accessibleText()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
        .accessibleCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NSLocalizedString("licenses_title", comment: "Open Source Licences") + ". " + NSLocalizedString("licenses_description", comment: "This app uses the following open source software"))
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(AccessibleTypography.body)
                .foregroundColor(AccessibleColors.primary)
                .accessibilityHidden(true)

            Text(title)
                .font(AccessibleTypography.headline)
                .foregroundColor(AccessibleColors.text)
                .accessibilityAddTraits(.isHeader)

            Spacer()
        }
        .padding(.horizontal, accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
        .padding(.top, 8)
    }

    // MARK: - License Card

    private func licenseCard(library: LicenseInfo) -> some View {
        let isExpanded = expandedLicenses.contains(library.id)

        return Button(action: {
            withAnimation(accessibilityManager.settings.reduceMotion ? nil : .easeInOut) {
                if isExpanded {
                    expandedLicenses.remove(library.id)
                } else {
                    expandedLicenses.insert(library.id)
                }
            }

            if accessibilityManager.settings.hapticFeedback {
                HapticFeedback.selection()
            }
        }, label: {
            VStack(alignment: .leading, spacing: 12) {
                // Header Row
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(library.name)
                            .font(AccessibleTypography.headline)
                            .foregroundColor(AccessibleColors.text)

                        HStack(spacing: 8) {
                            Text(library.version)
                                .font(AccessibleTypography.caption)
                                .foregroundColor(AccessibleColors.secondaryText)

                            Text("•")
                                .font(AccessibleTypography.caption)
                                .foregroundColor(AccessibleColors.secondaryText)

                            Text(library.licenseType)
                                .font(AccessibleTypography.caption)
                                .foregroundColor(AccessibleColors.primary)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(AccessibleTypography.footnote)
                        .foregroundColor(AccessibleColors.secondaryText)
                        .accessibilityHidden(true)
                }

                // Expanded Content
                if isExpanded {
                    Divider()
                        .background(AccessibleColors.secondaryText.opacity(0.3))
                        .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 12) {
                        // Copyright
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("licenses_copyright", comment: "Copyright"))
                                .font(AccessibleTypography.caption)
                                .foregroundColor(AccessibleColors.secondaryText)
                                .fontWeight(.semibold)

                            Text(library.copyright)
                                .font(AccessibleTypography.caption)
                                .foregroundColor(AccessibleColors.text)
                        }

                        // URL (if available)
                        if !library.url.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("licenses_website", comment: "Website"))
                                    .font(AccessibleTypography.caption)
                                    .foregroundColor(AccessibleColors.secondaryText)
                                    .fontWeight(.semibold)

                                Text(library.url)
                                    .font(AccessibleTypography.caption)
                                    .foregroundColor(AccessibleColors.primary)
                                    .underline()
                            }
                        }

                        // Full Licence Text
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("licenses_full_text", comment: "Licence Text"))
                                .font(AccessibleTypography.caption)
                                .foregroundColor(AccessibleColors.secondaryText)
                                .fontWeight(.semibold)

                            ScrollView {
                                Text(library.fullLicenseText)
                                    .font(AccessibleTypography.caption)
                                    .foregroundColor(AccessibleColors.text)
                                    .accessibleText()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 300)
                            .padding(8)
                            .background(AccessibleColors.background)
                            .cornerRadius(8)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
            .frame(minHeight: accessibilityManager.minimumTouchTargetSize())
            .accessibleCard()
        })
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.licenses.library_item.label", comment: "%@ library, version %@, licensed under %@"), library.name, library.version, library.licenseType))
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")
        .accessibilityAddTraits(.isButton)
        .onChange(of: isExpanded) { _, newValue in
            UIAccessibility.post(notification: .announcement,
                argument: newValue ? "Expanded" : "Collapsed")
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(AccessibleTypography.body)
                    .foregroundColor(AccessibleColors.primary)
                    .accessibilityHidden(true)

                Text(NSLocalizedString("licenses_footer_title", comment: "Licence Compliance"))
                    .font(AccessibleTypography.headline)
                    .foregroundColor(AccessibleColors.text)
            }

            Text(NSLocalizedString("licenses_footer_text", comment: "All licences are permissive and allow commercial use, modification, and distribution. Provii Wallet complies with all third-party licence requirements."))
                .font(AccessibleTypography.caption)
                .foregroundColor(AccessibleColors.secondaryText)
                .accessibleText()

            Text(String(format: NSLocalizedString("licenses_last_updated", comment: "Last updated: %@"), "2026-02-22"))
                .font(AccessibleTypography.caption)
                .foregroundColor(AccessibleColors.secondaryText)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(accessibilityManager.settings.increaseTouchTargets ? 20 : 16)
        .background(AccessibleColors.primary.opacity(0.1))
        .cornerRadius(accessibilityManager.settings.increaseTouchTargets ? 16 : 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: - License Texts

    private var apacheLicenseText: String {
        """
        Apache License
        Version 2.0, January 2004
        http://www.apache.org/licenses/

        TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

        1. Definitions.

           "License" shall mean the terms and conditions for use, reproduction,
           and distribution as defined by Sections 1 through 9 of this document.

           "Licensor" shall mean the copyright owner or entity authorized by
           the copyright owner that is granting the License.

           "Legal Entity" shall mean the union of the acting entity and all
           other entities that control, are controlled by, or are under common
           control with that entity. For the purposes of this definition,
           "control" means (i) the power, direct or indirect, to cause the
           direction or management of such entity, whether by contract or
           otherwise, or (ii) ownership of fifty percent (50%) or more of the
           outstanding shares, or (iii) beneficial ownership of such entity.

           "You" (or "Your") shall mean an individual or Legal Entity
           exercising permissions granted by this License.

           "Source" form shall mean the preferred form for making modifications,
           including but not limited to software source code, documentation
           source, and configuration files.

           "Object" form shall mean any form resulting from mechanical
           transformation or translation of a Source form, including but
           not limited to compiled object code, generated documentation,
           and conversions to other media types.

           "Work" shall mean the work of authorship, whether in Source or
           Object form, made available under the License, as indicated by a
           copyright notice that is included in or attached to the work
           (an example is provided in the Appendix below).

           "Derivative Works" shall mean any work, whether in Source or Object
           form, that is based on (or derived from) the Work and for which the
           editorial revisions, annotations, elaborations, or other modifications
           represent, as a whole, an original work of authorship. For the purposes
           of this License, Derivative Works shall not include works that remain
           separable from, or merely link (or bind by name) to the interfaces of,
           the Work and Derivative Works thereof.

           "Contribution" shall mean any work of authorship, including
           the original version of the Work and any modifications or additions
           to that Work or Derivative Works thereof, that is intentionally
           submitted to Licensor for inclusion in the Work by the copyright owner
           or by an individual or Legal Entity authorized to submit on behalf of
           the copyright owner. For the purposes of this definition, "submitted"
           means any form of electronic, verbal, or written communication sent
           to the Licensor or its representatives, including but not limited to
           communication on electronic mailing lists, source code control systems,
           and issue tracking systems that are managed by, or on behalf of, the
           Licensor for the purpose of discussing and improving the Work, but
           excluding communication that is conspicuously marked or otherwise
           designated in writing by the copyright owner as "Not a Contribution."

           "Contributor" shall mean Licensor and any individual or Legal Entity
           on behalf of whom a Contribution has been received by Licensor and
           subsequently incorporated within the Work.

        2. Grant of Copyright License. Subject to the terms and conditions of
           this License, each Contributor hereby grants to You a perpetual,
           worldwide, non-exclusive, no-charge, royalty-free, irrevocable
           copyright license to reproduce, prepare Derivative Works of,
           publicly display, publicly perform, sublicense, and distribute the
           Work and such Derivative Works in Source or Object form.

        3. Grant of Patent License. Subject to the terms and conditions of
           this License, each Contributor hereby grants to You a perpetual,
           worldwide, non-exclusive, no-charge, royalty-free, irrevocable
           (except as stated in this section) patent license to make, have made,
           use, offer to sell, sell, import, and otherwise transfer the Work,
           where such license applies only to those patent claims licensable
           by such Contributor that are necessarily infringed by their
           Contribution(s) alone or by combination of their Contribution(s)
           with the Work to which such Contribution(s) was submitted. If You
           institute patent litigation against any entity (including a
           cross-claim or counterclaim in a lawsuit) alleging that the Work
           or a Contribution incorporated within the Work constitutes direct
           or contributory patent infringement, then any patent licenses
           granted to You under this License for that Work shall terminate
           as of the date such litigation is filed.

        4. Redistribution. You may reproduce and distribute copies of the
           Work or Derivative Works thereof in any medium, with or without
           modifications, and in Source or Object form, provided that You
           meet the following conditions:

           (a) You must give any other recipients of the Work or
               Derivative Works a copy of this License; and

           (b) You must cause any modified files to carry prominent notices
               stating that You changed the files; and

           (c) You must retain, in the Source form of any Derivative Works
               that You distribute, all copyright, patent, trademark, and
               attribution notices from the Source form of the Work,
               excluding those notices that do not pertain to any part of
               the Derivative Works; and

           (d) If the Work includes a "NOTICE" text file as part of its
               distribution, then any Derivative Works that You distribute must
               include a readable copy of the attribution notices contained
               within such NOTICE file, excluding those notices that do not
               pertain to any part of the Derivative Works, in at least one
               of the following places: within a NOTICE text file distributed
               as part of the Derivative Works; within the Source form or
               documentation, if provided along with the Derivative Works; or,
               within a display generated by the Derivative Works, if and
               wherever such third-party notices normally appear. The contents
               of the NOTICE file are for informational purposes only and
               do not modify the License. You may add Your own attribution
               notices within Derivative Works that You distribute, alongside
               or as an addendum to the NOTICE text from the Work, provided
               that such additional attribution notices cannot be construed
               as modifying the License.

           You may add Your own copyright statement to Your modifications and
           may provide additional or different license terms and conditions
           for use, reproduction, or distribution of Your modifications, or
           for any such Derivative Works as a whole, provided Your use,
           reproduction, and distribution of the Work otherwise complies with
           the conditions stated in this License.

        5. Submission of Contributions. Unless You explicitly state otherwise,
           any Contribution intentionally submitted for inclusion in the Work
           by You to the Licensor shall be under the terms and conditions of
           this License, without any additional terms or conditions.
           Notwithstanding the above, nothing herein shall supersede or modify
           the terms of any separate license agreement you may have executed
           with Licensor regarding such Contributions.

        6. Trademarks. This License does not grant permission to use the trade
           names, trademarks, service marks, or product names of the Licensor,
           except as required for reasonable and customary use in describing the
           origin of the Work and reproducing the content of the NOTICE file.

        7. Disclaimer of Warranty. Unless required by applicable law or
           agreed to in writing, Licensor provides the Work (and each
           Contributor provides its Contributions) on an "AS IS" BASIS,
           WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
           implied, including, without limitation, any warranties or conditions
           of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
           PARTICULAR PURPOSE. You are solely responsible for determining the
           appropriateness of using or redistributing the Work and assume any
           risks associated with Your exercise of permissions under this License.

        8. Limitation of Liability. In no event and under no legal theory,
           whether in tort (including negligence), contract, or otherwise,
           unless required by applicable law (such as deliberate and grossly
           negligent acts) or agreed to in writing, shall any Contributor be
           liable to You for damages, including any direct, indirect, special,
           incidental, or consequential damages of any character arising as a
           result of this License or out of the use or inability to use the
           Work (including but not limited to damages for loss of goodwill,
           work stoppage, computer failure or malfunction, or any and all
           other commercial damages or losses), even if such Contributor
           has been advised of the possibility of such damages.

        9. Accepting Warranty or Additional Liability. While redistributing
           the Work or Derivative Works thereof, You may choose to offer,
           and charge a fee for, acceptance of support, warranty, indemnity,
           or other liability obligations and/or rights consistent with this
           License. However, in accepting such obligations, You may act only
           on Your own behalf and on Your sole responsibility, not on behalf
           of any other Contributor, and only if You agree to indemnify,
           defend, and hold each Contributor harmless for any liability
           incurred by, or claims asserted against, such Contributor by reason
           of your accepting any such warranty or additional liability.

        END OF TERMS AND CONDITIONS
        """
    }

    private var bsd3LicenseText: String {
        """
        Redistribution and use in source and binary forms, with or without \
        modification, are permitted provided that the following conditions are met:

        1. Redistributions of source code must retain the above copyright notice, \
        this list of conditions and the following disclaimer.

        2. Redistributions in binary form must reproduce the above copyright notice, \
        this list of conditions and the following disclaimer in the documentation \
        and/or other materials provided with the distribution.

        3. Neither the name of the copyright holder nor the names of its contributors \
        may be used to endorse or promote products derived from this software without \
        specific prior written permission.

        THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" \
        AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE \
        IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE \
        DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE \
        FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL \
        DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR \
        SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER \
        CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, \
        OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE \
        OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
        """
    }

    private var mpl2SummaryText: String {
        """
        This Source Code Form is subject to the terms of the Mozilla Public \
        License, v. 2.0. If a copy of the MPL was not distributed with this \
        file, You can obtain one at https://mozilla.org/MPL/2.0/.

        UniFFI is used as a build tool to generate Swift bindings for the \
        Rust Wallet SDK. The generated bindings are Provii's own code and \
        are not subject to the MPL. No modifications have been made to the \
        UniFFI source code.
        """
    }

    private var openFontLicenseText: String {
        """
        SIL OPEN FONT LICENSE
        Version 1.1 - 26 February 2007

        PREAMBLE
        The goals of the Open Font License (OFL) are to stimulate worldwide
        development of collaborative font projects, to support the font creation
        efforts of academic and linguistic communities, and to provide a free and
        open framework in which fonts may be shared and improved in partnership
        with others.

        The OFL allows the licensed fonts to be used, studied, modified and
        redistributed freely as long as they are not sold by themselves. The
        fonts, including any derivative works, can be bundled, embedded,
        redistributed and/or sold with any software provided that any reserved
        names are not used by derivative works. The fonts and derivatives,
        however, cannot be released under any other type of license. The
        requirement for fonts to remain under this license does not apply
        to any document created using the fonts or their derivatives.

        PERMISSION & CONDITIONS
        Permission is hereby granted, free of charge, to any person obtaining
        a copy of the Font Software, to use, study, copy, merge, embed, modify,
        redistribute, and sell modified and unmodified copies of the Font
        Software, subject to the following conditions:

        1) Neither the Font Software nor any of its individual components,
        in Original or Modified Versions, may be sold by itself.

        2) Original or Modified Versions of the Font Software may be bundled,
        redistributed and/or sold with any software, provided that each copy
        contains the above copyright notice and this license. These can be
        included either as stand-alone text files, human-readable headers or
        in the appropriate machine-readable metadata fields within text or
        binary files as long as those fields can be easily viewed by the user.

        3) No Modified Version of the Font Software may use the Reserved Font
        Name(s) unless explicit written permission is granted by the corresponding
        Copyright Holder. This restriction only applies to the primary font name as
        presented to the users.

        4) The name(s) of the Copyright Holder(s) or the Author(s) of the Font
        Software shall not be used to promote, endorse or advertise any
        Modified Version, except to acknowledge the contribution(s) of the
        Copyright Holder(s) and the Author(s) or with their explicit written
        permission.

        5) The Font Software, modified or unmodified, in part or in whole,
        must be distributed entirely under this license, and must not be
        distributed under any other license. The requirement for fonts to
        remain under this license does not apply to any document created
        using the Font Software.

        TERMINATION
        This license becomes null and void if any of the above conditions are
        not met.

        DISCLAIMER
        THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
        EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF
        MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT
        OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL THE
        COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
        INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL
        DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
        FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM
        OTHER DEALINGS IN THE FONT SOFTWARE.
        """
    }
}

// MARK: - License Info Model

struct LicenseInfo: Identifiable {
    let id = UUID().uuidString
    let name: String
    let version: String
    let licenseType: String
    let copyright: String
    let url: String
    let fullLicenseText: String
}

// MARK: - Preview

#if DEBUG
struct LicensesView_Previews: PreviewProvider {
    static var previews: some View {
        LicensesView()
            .environmentObject(AccessibilityManager.shared)
    }
}
#endif
