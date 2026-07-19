import AppKit
import UniformTypeIdentifiers

final class ThemeEditorWindowController: NSWindowController {
    private let layoutStyles: [(id: String, title: String, visualStyle: String)] = [
        ("stage", "未来舞台", "miku-07"),
        ("qq-classic", "经典蓝 QQ 工作台", "classic-blue-07")
    ]
    private let engine: EngineController
    private let onSaved: () -> Void
    private var draft = ThemeDraft.blank
    private var isSaving = false

    private let preview = NSImageView()
    private let imagePathLabel = NSTextField(labelWithString: "请选择一张背景图片")
    private let userAvatarPreview = NSImageView()
    private let assistantAvatarPreview = NSImageView()
    private let userAvatarPathLabel = NSTextField(labelWithString: "未设置")
    private let assistantAvatarPathLabel = NSTextField(labelWithString: "未设置")
    private let nameField = NSTextField()
    private let backgroundNameField = NSTextField()
    private let stylePopup = NSPopUpButton()
    private let brandSubtitleField = NSTextField()
    private let taglineField = NSTextField()
    private let projectPrefixField = NSTextField()
    private let projectLabelField = NSTextField()
    private let statusTextField = NSTextField()
    private let quoteField = NSTextField()
    private let headerTitleField = NSTextField()
    private let headerSubtitleField = NSTextField()
    private let headerStatusField = NSTextField()
    private let opacitySlider = NSSlider(value: 76, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let blurSlider = NSSlider(value: 14, minValue: 0, maxValue: 40, target: nil, action: nil)
    private let opacityValueLabel = NSTextField(labelWithString: "76%")
    private let blurValueLabel = NSTextField(labelWithString: "14 px")
    private let retroHeaderCheckbox = NSButton(checkboxWithTitle: "双层经典标题区", target: nil, action: nil)
    private let toolbarCheckbox = NSButton(checkboxWithTitle: "快捷工具栏", target: nil, action: nil)
    private let threePaneCheckbox = NSButton(checkboxWithTitle: "任务页三栏布局", target: nil, action: nil)
    private let autoSummaryCheckbox = NSButton(checkboxWithTitle: "自动打开原生置顶摘要", target: nil, action: nil)
    private let companionCheckbox = NSButton(checkboxWithTitle: "右侧 Codex 伙伴卡", target: nil, action: nil)
    private let profileCheckbox = NSButton(checkboxWithTitle: "左下在线资料卡", target: nil, action: nil)
    private let homePetCheckbox = NSButton(checkboxWithTitle: "新建任务页角色", target: nil, action: nil)
    private let layoutMinWidthField = NSTextField()
    private let layoutRightWidthField = NSTextField()
    private let layoutWindowTitleField = NSTextField()
    private let layoutProfileNameField = NSTextField()
    private let layoutProfileStatusField = NSTextField()
    private let layoutCompanionTitleField = NSTextField()
    private let layoutCompanionStatusField = NSTextField()
    private let layoutComponentsStack = NSStackView()
    private let layoutAvailabilityLabel = NSTextField(wrappingLabelWithString: "")
    private let applyCheckbox = NSButton(checkboxWithTitle: "保存后立即应用", target: nil, action: nil)
    private let saveButton = NSButton(title: "保存主题", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    private let tabController = NSTabViewController()
    private var colorWells: [String: NSColorWell] = [:]
    private var colorValueLabels: [String: NSTextField] = [:]

    init(engine: EngineController, onSaved: @escaping () -> Void) {
        self.engine = engine
        self.onSaved = onSaved
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex Dream Skin 主题工作室"
        window.minSize = NSSize(width: 820, height: 620)
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        NSColorPanel.shared.showsAlpha = true
        buildInterface()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        do {
            draft = try engine.loadActiveTheme()
            populateControls()
            statusLabel.stringValue = "已载入当前主题"
            statusLabel.textColor = .secondaryLabelColor
        } catch {
            draft = .blank
            populateControls()
            statusLabel.stringValue = error.localizedDescription
            statusLabel.textColor = .systemRed
        }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildInterface() {
        guard let contentView = window?.contentView else { return }

        let title = NSTextField(labelWithString: "主题工作室")
        title.font = .systemFont(ofSize: 24, weight: .bold)
        let subtitle = NSTextField(labelWithString: "创建自己的颜色、文案、效果与背景组合")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor

        let heading = NSStackView(views: [title, subtitle])
        heading.orientation = .vertical
        heading.alignment = .leading
        heading.spacing = 4

        let previewPanel = buildPreviewPanel()
        let tabs = buildTabs()
        let main = NSStackView(views: [previewPanel, tabs])
        main.orientation = .horizontal
        main.alignment = .top
        main.spacing = 22
        previewPanel.widthAnchor.constraint(equalToConstant: 300).isActive = true

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.lineBreakMode = .byTruncatingMiddle

        let newButton = NSButton(title: "新建主题", target: self, action: #selector(newTheme))
        newButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "新建主题")
        newButton.imagePosition = .imageLeading

        let closeButton = NSButton(title: "关闭", target: self, action: #selector(closeEditor))
        saveButton.target = self
        saveButton.action = #selector(saveTheme)
        saveButton.keyEquivalent = "\r"
        saveButton.bezelStyle = .rounded
        saveButton.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "保存主题")
        saveButton.imagePosition = .imageLeading
        applyCheckbox.state = .on

        let actions = NSStackView(views: [newButton, statusLabel, applyCheckbox, closeButton, saveButton])
        actions.orientation = .horizontal
        actions.alignment = .centerY
        actions.spacing = 10
        statusLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        applyCheckbox.setContentHuggingPriority(.required, for: .horizontal)
        closeButton.setContentHuggingPriority(.required, for: .horizontal)
        saveButton.setContentHuggingPriority(.required, for: .horizontal)

        let root = NSStackView(views: [heading, main, separator(), actions])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 16
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
            heading.widthAnchor.constraint(equalTo: root.widthAnchor),
            main.widthAnchor.constraint(equalTo: root.widthAnchor),
            main.heightAnchor.constraint(greaterThanOrEqualToConstant: 490),
            tabs.widthAnchor.constraint(greaterThanOrEqualToConstant: 470),
            tabs.heightAnchor.constraint(equalTo: main.heightAnchor),
            actions.widthAnchor.constraint(equalTo: root.widthAnchor)
        ])
    }

    private func buildPreviewPanel() -> NSView {
        preview.imageScaling = .scaleProportionallyUpOrDown
        preview.imageAlignment = .alignCenter
        preview.wantsLayer = true
        preview.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        preview.layer?.cornerRadius = 6
        preview.layer?.borderWidth = 1
        preview.layer?.borderColor = NSColor.separatorColor.cgColor
        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.heightAnchor.constraint(equalToConstant: 180).isActive = true

        imagePathLabel.font = .systemFont(ofSize: 11)
        imagePathLabel.textColor = .secondaryLabelColor
        imagePathLabel.lineBreakMode = .byTruncatingMiddle
        imagePathLabel.maximumNumberOfLines = 2

        let chooseButton = NSButton(title: "选择背景图片", target: self, action: #selector(chooseImage))
        chooseButton.image = NSImage(systemSymbolName: "photo", accessibilityDescription: "选择背景图片")
        chooseButton.imagePosition = .imageLeading

        configureTextField(nameField, placeholder: "例如：深海工作台")
        configureTextField(backgroundNameField, placeholder: "例如：蓝色海面")
        stylePopup.addItems(withTitles: layoutStyles.map { $0.title })
        stylePopup.target = self
        stylePopup.action = #selector(layoutSelectionChanged)

        let stack = NSStackView(views: [
            sectionTitle("背景预览"), preview, imagePathLabel, chooseButton,
            separator(),
            fieldGroup("主题名称", nameField),
            fieldGroup("背景名称", backgroundNameField),
            fieldGroup("布局主题", stylePopup)
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        preview.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        imagePathLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        chooseButton.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        nameField.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        backgroundNameField.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        stylePopup.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }

    private func buildTabs() -> NSView {
        tabController.tabStyle = .segmentedControlOnTop
        tabController.addTabViewItem(tab(title: "颜色搭配", view: buildColorsView()))
        tabController.addTabViewItem(tab(title: "主题文案", view: buildCopyView()))
        tabController.addTabViewItem(tab(title: "对话头像", view: buildAvatarsView()))
        tabController.addTabViewItem(tab(title: "界面效果", view: buildEffectsView()))
        tabController.addTabViewItem(tab(title: "布局组件", view: buildLayoutComponentsView()))
        return tabController.view
    }

    private func buildColorsView() -> NSView {
        let definitions = [
            ("background", "页面底色"), ("panel", "主面板"),
            ("panelAlt", "次级面板"), ("accent", "主强调色"),
            ("accentAlt", "辅助强调色"), ("secondary", "次要色"),
            ("highlight", "高亮色"), ("text", "主要文字"),
            ("muted", "次要文字"), ("line", "边框与分隔线")
        ]
        var rows: [[NSView]] = []
        for index in stride(from: 0, to: definitions.count, by: 2) {
            rows.append([
                colorControl(key: definitions[index].0, label: definitions[index].1),
                colorControl(key: definitions[index + 1].0, label: definitions[index + 1].1)
            ])
        }
        let grid = NSGridView(views: rows)
        grid.rowSpacing = 15
        grid.columnSpacing = 28
        grid.column(at: 0).xPlacement = .fill
        grid.column(at: 1).xPlacement = .fill

        let note = NSTextField(wrappingLabelWithString: "点击色块即可打开系统调色板。边框色支持透明度，其余颜色会保存为不透明色。")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [sectionTitle("完整配色"), note, grid])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        grid.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        note.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return inset(stack)
    }

    private func buildCopyView() -> NSView {
        configureTextField(brandSubtitleField, placeholder: "品牌副标题，可留空")
        configureTextField(taglineField, placeholder: "首页主题说明，可留空")
        configureTextField(projectPrefixField, placeholder: "项目区域前缀，可留空")
        configureTextField(projectLabelField, placeholder: "选择项目按钮文字，可留空")
        configureTextField(statusTextField, placeholder: "首页状态文字，可留空")
        configureTextField(quoteField, placeholder: "主题短句，可留空")

        let stack = NSStackView(views: [
            sectionTitle("首页与项目文案"),
            fieldGroup("品牌副标题", brandSubtitleField),
            fieldGroup("主题说明", taglineField),
            fieldGroup("项目区域前缀", projectPrefixField),
            fieldGroup("项目按钮", projectLabelField),
            fieldGroup("状态文字", statusTextField),
            fieldGroup("主题短句", quoteField)
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        for field in [brandSubtitleField, taglineField, projectPrefixField, projectLabelField, statusTextField, quoteField] {
            field.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return inset(stack)
    }

    private func buildAvatarsView() -> NSView {
        let grid = NSGridView(views: [[
            avatarControl(
                title: "我的提问",
                preview: userAvatarPreview,
                pathLabel: userAvatarPathLabel,
                chooseAction: #selector(chooseUserAvatar),
                removeAction: #selector(removeUserAvatar)
            ),
            avatarControl(
                title: "Codex 回答",
                preview: assistantAvatarPreview,
                pathLabel: assistantAvatarPathLabel,
                chooseAction: #selector(chooseAssistantAvatar),
                removeAction: #selector(removeAssistantAvatar)
            )
        ]])
        grid.columnSpacing = 34
        grid.column(at: 0).xPlacement = .fill
        grid.column(at: 1).xPlacement = .fill

        let stack = NSStackView(views: [sectionTitle("一问一答头像"), grid])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        grid.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return inset(stack)
    }

    private func avatarControl(
        title: String,
        preview: NSImageView,
        pathLabel: NSTextField,
        chooseAction: Selector,
        removeAction: Selector
    ) -> NSView {
        preview.imageScaling = .scaleProportionallyUpOrDown
        preview.imageAlignment = .alignCenter
        preview.wantsLayer = true
        preview.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        preview.layer?.cornerRadius = 56
        preview.layer?.masksToBounds = true
        preview.layer?.borderWidth = 1
        preview.layer?.borderColor = NSColor.separatorColor.cgColor
        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.widthAnchor.constraint(equalToConstant: 112).isActive = true
        preview.heightAnchor.constraint(equalToConstant: 112).isActive = true

        pathLabel.font = .systemFont(ofSize: 11)
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.alignment = .center
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.maximumNumberOfLines = 2

        let chooseButton = NSButton(title: "选择图片", target: self, action: chooseAction)
        chooseButton.image = NSImage(systemSymbolName: "photo.badge.plus", accessibilityDescription: "选择头像图片")
        chooseButton.imagePosition = .imageLeading
        let removeButton = NSButton(title: "移除", target: self, action: removeAction)
        removeButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "移除头像")
        removeButton.imagePosition = .imageLeading
        let actions = NSStackView(views: [chooseButton, removeButton])
        actions.orientation = .horizontal
        actions.alignment = .centerY
        actions.spacing = 8

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.alignment = .center
        let stack = NSStackView(views: [label, preview, pathLabel, actions])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        pathLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }

    private func buildEffectsView() -> NSView {
        configureTextField(headerTitleField, placeholder: "左侧标题，可留空")
        configureTextField(headerSubtitleField, placeholder: "左侧副标题，可留空")
        configureTextField(headerStatusField, placeholder: "右侧状态，可留空")
        opacitySlider.target = self
        opacitySlider.action = #selector(effectSliderChanged)
        blurSlider.target = self
        blurSlider.action = #selector(effectSliderChanged)
        opacityValueLabel.alignment = .right
        blurValueLabel.alignment = .right

        let stack = NSStackView(views: [
            sectionTitle("任务阅读区"),
            sliderGroup("不透明度", slider: opacitySlider, valueLabel: opacityValueLabel),
            sliderGroup("磨砂模糊", slider: blurSlider, valueLabel: blurValueLabel),
            separator(),
            sectionTitle("顶部文字"),
            fieldGroup("左侧标题", headerTitleField),
            fieldGroup("左侧副标题", headerSubtitleField),
            fieldGroup("右侧状态", headerStatusField)
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        for field in [headerTitleField, headerSubtitleField, headerStatusField] {
            field.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return inset(stack)
    }

    private func buildLayoutComponentsView() -> NSView {
        layoutAvailabilityLabel.font = .systemFont(ofSize: 11)
        layoutAvailabilityLabel.textColor = .secondaryLabelColor

        for field in [layoutMinWidthField, layoutRightWidthField] {
            configureTextField(field, placeholder: "像素")
            field.formatter = NumberFormatter()
        }
        configureTextField(layoutWindowTitleField, placeholder: "Codex 2007")
        configureTextField(layoutProfileNameField, placeholder: "留空则使用当前 Codex 账号名")
        configureTextField(layoutProfileStatusField, placeholder: "在线")
        configureTextField(layoutCompanionTitleField, placeholder: "Codex 伙伴")
        configureTextField(layoutCompanionStatusField, placeholder: "在线 · 随时待命")

        let toggles = NSGridView(views: [
            [retroHeaderCheckbox, toolbarCheckbox],
            [threePaneCheckbox, autoSummaryCheckbox],
            [companionCheckbox, profileCheckbox],
            [homePetCheckbox, NSView()]
        ])
        toggles.rowSpacing = 8
        toggles.columnSpacing = 22
        toggles.column(at: 0).xPlacement = .leading
        toggles.column(at: 1).xPlacement = .leading

        let widths = NSGridView(views: [[
            fieldGroup("启用三栏的最小窗口宽度", layoutMinWidthField),
            fieldGroup("右栏宽度", layoutRightWidthField)
        ]])
        widths.columnSpacing = 18
        widths.column(at: 0).xPlacement = .fill
        widths.column(at: 1).xPlacement = .fill

        let reset = NSButton(title: "恢复经典蓝默认组件", target: self, action: #selector(resetLayoutComponents))
        reset.image = NSImage(systemSymbolName: "arrow.counterclockwise", accessibilityDescription: "恢复经典蓝默认组件")
        reset.imagePosition = .imageLeading

        layoutComponentsStack.setViews([
            sectionTitle("经典蓝组件"), layoutAvailabilityLabel, toggles, widths,
            separator(), fieldGroup("窗口标题", layoutWindowTitleField),
            fieldGroup("资料卡名称", layoutProfileNameField),
            fieldGroup("资料卡状态", layoutProfileStatusField),
            fieldGroup("伙伴卡标题", layoutCompanionTitleField),
            fieldGroup("伙伴卡状态", layoutCompanionStatusField), reset
        ], in: .top)
        layoutComponentsStack.orientation = .vertical
        layoutComponentsStack.alignment = .leading
        layoutComponentsStack.spacing = 10
        for field in [layoutWindowTitleField, layoutProfileNameField, layoutProfileStatusField,
                      layoutCompanionTitleField, layoutCompanionStatusField] {
            field.widthAnchor.constraint(equalTo: layoutComponentsStack.widthAnchor).isActive = true
        }
        widths.widthAnchor.constraint(equalTo: layoutComponentsStack.widthAnchor).isActive = true
        return inset(layoutComponentsStack)
    }

    private func tab(title: String, view: NSView) -> NSTabViewItem {
        let item = NSTabViewItem(viewController: NSViewController())
        item.label = title
        item.viewController?.view = view
        return item
    }

    private func inset(_ view: NSView) -> NSView {
        let container = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            view.topAnchor.constraint(equalTo: container.topAnchor, constant: 18),
            view.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -18)
        ])
        return container
    }

    private func configureTextField(_ field: NSTextField, placeholder: String) {
        field.placeholderString = placeholder
        field.bezelStyle = .roundedBezel
        field.font = .systemFont(ofSize: 13)
    }

    private func fieldGroup(_ label: String, _ control: NSView) -> NSView {
        let title = NSTextField(labelWithString: label)
        title.font = .systemFont(ofSize: 12, weight: .medium)
        let stack = NSStackView(views: [title, control])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 5
        return stack
    }

    private func colorControl(key: String, label: String) -> NSView {
        let title = NSTextField(labelWithString: label)
        title.font = .systemFont(ofSize: 12, weight: .medium)
        let well = NSColorWell()
        well.identifier = NSUserInterfaceItemIdentifier(key)
        well.target = self
        well.action = #selector(colorChanged)
        well.translatesAutoresizingMaskIntoConstraints = false
        well.widthAnchor.constraint(equalToConstant: 44).isActive = true
        well.heightAnchor.constraint(equalToConstant: 28).isActive = true
        let value = NSTextField(labelWithString: "#000000")
        value.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        value.textColor = .secondaryLabelColor
        value.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [well, value])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        colorWells[key] = well
        colorValueLabels[key] = value

        let stack = NSStackView(views: [title, row])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 5
        return stack
    }

    private func sliderGroup(_ label: String, slider: NSSlider, valueLabel: NSTextField) -> NSView {
        let title = NSTextField(labelWithString: label)
        title.font = .systemFont(ofSize: 12, weight: .medium)
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true
        let row = NSStackView(views: [slider, valueLabel])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        let stack = NSStackView(views: [title, row])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 5
        row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }

    private func sectionTitle(_ value: String) -> NSTextField {
        let label = NSTextField(labelWithString: value)
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        return label
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return box
    }

    private func populateControls() {
        nameField.stringValue = draft.name
        backgroundNameField.stringValue = draft.backgroundName
        stylePopup.selectItem(at: layoutStyles.firstIndex { $0.id == draft.layoutId } ?? 0)
        brandSubtitleField.stringValue = draft.brandSubtitle
        taglineField.stringValue = draft.tagline
        projectPrefixField.stringValue = draft.projectPrefix
        projectLabelField.stringValue = draft.projectLabel
        statusTextField.stringValue = draft.statusText
        quoteField.stringValue = draft.quote
        headerTitleField.stringValue = draft.headerText.title ?? ""
        headerSubtitleField.stringValue = draft.headerText.subtitle ?? ""
        headerStatusField.stringValue = draft.headerText.status ?? ""
        opacitySlider.doubleValue = draft.effects.taskPanelOpacity * 100
        blurSlider.doubleValue = draft.effects.taskPanelBlur
        applyColors(draft.colors)
        updateEffectLabels()
        updateImagePreview()
        updateAvatarPreviews()
        populateLayoutComponents()
        updateLayoutComponentAvailability()
    }

    private func populateLayoutComponents() {
        let value = draft.layoutComponents
        retroHeaderCheckbox.state = value.retroHeader ? .on : .off
        toolbarCheckbox.state = value.toolbar ? .on : .off
        threePaneCheckbox.state = value.threePane ? .on : .off
        autoSummaryCheckbox.state = value.autoOpenSummary ? .on : .off
        companionCheckbox.state = value.companion ? .on : .off
        profileCheckbox.state = value.profileCard ? .on : .off
        homePetCheckbox.state = value.homePet ? .on : .off
        layoutMinWidthField.doubleValue = value.minWidth
        layoutRightWidthField.doubleValue = value.rightWidth
        layoutWindowTitleField.stringValue = value.windowTitle
        layoutProfileNameField.stringValue = value.profileName
        layoutProfileStatusField.stringValue = value.profileStatus
        layoutCompanionTitleField.stringValue = value.companionTitle
        layoutCompanionStatusField.stringValue = value.companionStatus
    }

    private func selectedLayoutId() -> String {
        let index = stylePopup.indexOfSelectedItem
        return layoutStyles.indices.contains(index) ? layoutStyles[index].id : "stage"
    }

    private func updateLayoutComponentAvailability() {
        let enabled = selectedLayoutId() == "qq-classic"
        layoutAvailabilityLabel.stringValue = enabled
            ? "这些设置只控制经典蓝布局；颜色、背景和对话头像仍在其他分页编辑。"
            : "未来舞台使用统一舞台结构，没有经典蓝专属组件。切换到“经典蓝 QQ 工作台”后可编辑。"
        for view in layoutComponentsStack.arrangedSubviews where view !== layoutAvailabilityLabel {
            view.alphaValue = enabled ? 1 : 0.42
            setEnabledRecursively(view, enabled: enabled)
        }
    }

    private func setEnabledRecursively(_ view: NSView, enabled: Bool) {
        if let control = view as? NSControl { control.isEnabled = enabled }
        view.subviews.forEach { setEnabledRecursively($0, enabled: enabled) }
    }

    @objc private func layoutSelectionChanged() {
        updateLayoutComponentAvailability()
    }

    @objc private func resetLayoutComponents() {
        draft.layoutComponents = .qqClassic
        populateLayoutComponents()
    }

    private func applyColors(_ colors: ThemeColors) {
        let values = [
            "background": colors.background, "panel": colors.panel, "panelAlt": colors.panelAlt,
            "accent": colors.accent, "accentAlt": colors.accentAlt, "secondary": colors.secondary,
            "highlight": colors.highlight, "text": colors.text, "muted": colors.muted, "line": colors.line
        ]
        for (key, css) in values {
            colorWells[key]?.color = NSColor(css: css) ?? .black
            updateColorLabel(for: key)
        }
    }

    private func updateImagePreview() {
        if let imageURL = draft.imageURL, let image = NSImage(contentsOf: imageURL) {
            preview.image = image
            imagePathLabel.stringValue = imageURL.path
        } else {
            preview.image = NSImage(systemSymbolName: "photo.on.rectangle.angled", accessibilityDescription: "未选择背景")
            preview.contentTintColor = .tertiaryLabelColor
            imagePathLabel.stringValue = "请选择一张背景图片"
        }
    }

    @objc private func chooseImage() {
        let panel = NSOpenPanel()
        panel.title = "选择主题背景图片"
        panel.prompt = "选择"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK, let url = panel.url {
            draft.imageURL = url
            if backgroundNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                backgroundNameField.stringValue == "我的背景" {
                backgroundNameField.stringValue = url.deletingPathExtension().lastPathComponent
            }
            updateImagePreview()
        }
    }

    private func updateAvatarPreviews() {
        updateAvatarPreview(userAvatarPreview, label: userAvatarPathLabel, url: draft.userAvatarURL, role: "我的提问")
        updateAvatarPreview(assistantAvatarPreview, label: assistantAvatarPathLabel, url: draft.assistantAvatarURL, role: "Codex 回答")
    }

    private func updateAvatarPreview(_ preview: NSImageView, label: NSTextField, url: URL?, role: String) {
        if let url, let image = NSImage(contentsOf: url) {
            preview.image = image
            preview.contentTintColor = nil
            label.stringValue = url.path
        } else {
            preview.image = NSImage(systemSymbolName: "person.crop.circle", accessibilityDescription: "\(role)头像未设置")
            preview.contentTintColor = .tertiaryLabelColor
            label.stringValue = "未设置"
        }
    }

    private func chooseAvatar(for role: String, apply: (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "选择\(role)头像"
        panel.prompt = "选择"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK, let url = panel.url {
            apply(url)
            updateAvatarPreviews()
        }
    }

    @objc private func chooseUserAvatar() {
        chooseAvatar(for: "我的提问") { draft.userAvatarURL = $0 }
    }

    @objc private func chooseAssistantAvatar() {
        chooseAvatar(for: "Codex 回答") { draft.assistantAvatarURL = $0 }
    }

    @objc private func removeUserAvatar() {
        draft.userAvatarURL = nil
        updateAvatarPreviews()
    }

    @objc private func removeAssistantAvatar() {
        draft.assistantAvatarURL = nil
        updateAvatarPreviews()
    }

    @objc private func newTheme() {
        draft = .blank
        populateControls()
        statusLabel.stringValue = "新主题尚未保存"
        statusLabel.textColor = .secondaryLabelColor
    }

    @objc private func effectSliderChanged() {
        updateEffectLabels()
    }

    private func updateEffectLabels() {
        opacityValueLabel.stringValue = "\(Int(opacitySlider.doubleValue.rounded()))%"
        blurValueLabel.stringValue = "\(Int(blurSlider.doubleValue.rounded())) px"
    }

    @objc private func colorChanged(_ sender: NSColorWell) {
        guard let key = sender.identifier?.rawValue else { return }
        updateColorLabel(for: key)
    }

    private func updateColorLabel(for key: String) {
        guard let well = colorWells[key] else { return }
        colorValueLabels[key]?.stringValue = well.color.cssString(includeAlpha: key == "line")
    }

    @objc private func saveTheme() {
        guard !isSaving else { return }
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            statusLabel.stringValue = "请填写主题名称"
            statusLabel.textColor = .systemRed
            return
        }
        guard draft.imageURL != nil else {
            statusLabel.stringValue = "请先选择背景图片"
            statusLabel.textColor = .systemRed
            return
        }

        draft.name = String(name.prefix(80))
        let backgroundName = backgroundNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.backgroundName = backgroundName.isEmpty ? "我的背景" : String(backgroundName.prefix(80))
        let selectedStyleIndex = stylePopup.indexOfSelectedItem
        let selectedLayout = layoutStyles.indices.contains(selectedStyleIndex)
            ? layoutStyles[selectedStyleIndex]
            : layoutStyles[0]
        draft.layoutId = selectedLayout.id
        draft.visualStyle = selectedLayout.visualStyle
        draft.brandSubtitle = String(brandSubtitleField.stringValue.prefix(80))
        draft.tagline = String(taglineField.stringValue.prefix(160))
        draft.projectPrefix = String(projectPrefixField.stringValue.prefix(80))
        draft.projectLabel = String(projectLabelField.stringValue.prefix(80))
        draft.statusText = String(statusTextField.stringValue.prefix(80))
        draft.quote = String(quoteField.stringValue.prefix(80))
        draft.headerText = ThemeHeaderText(
            title: String(headerTitleField.stringValue.prefix(80)),
            subtitle: String(headerSubtitleField.stringValue.prefix(80)),
            status: String(headerStatusField.stringValue.prefix(80))
        )
        draft.effects = ThemeEffects(
            taskPanelOpacity: opacitySlider.doubleValue / 100,
            taskPanelBlur: blurSlider.doubleValue
        )
        let minWidth = min(max(layoutMinWidthField.doubleValue, 1080), 2400)
        let rightWidth = min(max(layoutRightWidthField.doubleValue, 272), 420)
        draft.layoutComponents = ThemeLayoutComponents(
            retroHeader: retroHeaderCheckbox.state == .on,
            toolbar: toolbarCheckbox.state == .on,
            threePane: threePaneCheckbox.state == .on,
            autoOpenSummary: autoSummaryCheckbox.state == .on,
            companion: companionCheckbox.state == .on,
            profileCard: profileCheckbox.state == .on,
            homePet: homePetCheckbox.state == .on,
            minWidth: minWidth,
            rightWidth: rightWidth,
            windowTitle: String(layoutWindowTitleField.stringValue.prefix(60)),
            profileName: String(layoutProfileNameField.stringValue.prefix(48)),
            profileStatus: String(layoutProfileStatusField.stringValue.prefix(32)),
            companionTitle: String(layoutCompanionTitleField.stringValue.prefix(48)),
            companionStatus: String(layoutCompanionStatusField.stringValue.prefix(64))
        )
        draft.colors = ThemeColors(
            background: colorValue("background"),
            panel: colorValue("panel"),
            panelAlt: colorValue("panelAlt"),
            accent: colorValue("accent"),
            accentAlt: colorValue("accentAlt"),
            secondary: colorValue("secondary"),
            highlight: colorValue("highlight"),
            text: colorValue("text"),
            muted: colorValue("muted"),
            line: colorValue("line", includeAlpha: true)
        )

        isSaving = true
        saveButton.isEnabled = false
        statusLabel.stringValue = applyCheckbox.state == .on ? "正在保存并应用..." : "正在保存..."
        statusLabel.textColor = .secondaryLabelColor
        engine.saveTheme(draft, applyImmediately: applyCheckbox.state == .on) { [weak self] result in
            guard let self else { return }
            self.isSaving = false
            self.saveButton.isEnabled = true
            switch result {
            case .success(let scriptResult) where scriptResult.succeeded:
                self.statusLabel.stringValue = self.applyCheckbox.state == .on ? "主题已保存并应用" : "主题已保存"
                self.statusLabel.textColor = .systemGreen
                self.onSaved()
            case .success(let scriptResult):
                let detail = scriptResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                self.statusLabel.stringValue = detail.isEmpty ? "保存失败（\(scriptResult.exitCode)）" : String(detail.suffix(180))
                self.statusLabel.textColor = .systemRed
            case .failure(let error):
                self.statusLabel.stringValue = error.localizedDescription
                self.statusLabel.textColor = .systemRed
            }
        }
    }

    private func colorValue(_ key: String, includeAlpha: Bool = false) -> String {
        colorWells[key]?.color.cssString(includeAlpha: includeAlpha) ?? "#000000"
    }

    @objc private func closeEditor() {
        close()
    }
}

private extension NSColor {
    convenience init?(css: String) {
        let value = css.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#"), value.count == 7, let number = Int(value.dropFirst(), radix: 16) {
            let red = CGFloat((number >> 16) & 255) / 255.0
            let green = CGFloat((number >> 8) & 255) / 255.0
            let blue = CGFloat(number & 255) / 255.0
            self.init(
                srgbRed: red,
                green: green,
                blue: blue,
                alpha: 1
            )
            return
        }
        let lower = value.lowercased()
        guard lower.hasPrefix("rgb"),
              let open = lower.firstIndex(of: "("),
              let close = lower.lastIndex(of: ")") else { return nil }
        let components = lower[lower.index(after: open)..<close]
            .split(separator: ",")
            .map { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        guard components.count >= 3,
              let red = components[0], let green = components[1], let blue = components[2] else { return nil }
        let redComponent = CGFloat(red / 255.0)
        let greenComponent = CGFloat(green / 255.0)
        let blueComponent = CGFloat(blue / 255.0)
        let alphaComponent = CGFloat(components.count > 3 ? components[3] ?? 1 : 1)
        self.init(
            srgbRed: redComponent,
            green: greenComponent,
            blue: blueComponent,
            alpha: alphaComponent
        )
    }

    func cssString(includeAlpha: Bool) -> String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#000000" }
        let red = Int((rgb.redComponent * 255).rounded())
        let green = Int((rgb.greenComponent * 255).rounded())
        let blue = Int((rgb.blueComponent * 255).rounded())
        if includeAlpha, rgb.alphaComponent < 0.995 {
            return String(format: "rgba(%d, %d, %d, %.2f)", red, green, blue, rgb.alphaComponent)
        }
        return String(format: "#%02x%02x%02x", red, green, blue)
    }
}
