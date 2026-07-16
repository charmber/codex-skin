ObjC.import("AppKit");

function numericArgument(value, fallback, minimum, maximum) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(maximum, Math.max(minimum, parsed));
}

function label(text, frame) {
  const field = $.NSTextField.labelWithString(text);
  field.frame = frame;
  return field;
}

function valueField(value, maximumFractionDigits, frame) {
  const field = label("", frame);
  const formatter = $.NSNumberFormatter.alloc.init;
  formatter.numberStyle = $.NSNumberFormatterDecimalStyle;
  formatter.minimumFractionDigits = 0;
  formatter.maximumFractionDigits = maximumFractionDigits;
  field.formatter = formatter;
  field.alignment = $.NSTextAlignmentRight;
  field.font = $.NSFont.monospacedDigitSystemFontOfSizeWeight(13, $.NSFontWeightMedium);
  field.doubleValue = value;
  return field;
}

function slider(value, maximum, tickCount, frame, accessibilityLabel, outputField) {
  const control = $.NSSlider.sliderWithValueMinValueMaxValueTargetAction(
    value,
    0,
    maximum,
    outputField,
    $.NSSelectorFromString("takeDoubleValueFrom:"),
  );
  control.frame = frame;
  control.continuous = true;
  control.numberOfTickMarks = tickCount;
  control.tickMarkPosition = $.NSTickMarkBelow;
  control.allowsTickMarkValuesOnly = false;
  control.setAccessibilityLabel(accessibilityLabel);
  return control;
}

function showDialog(currentOpacity, currentBlur) {
  const application = $.NSApplication.sharedApplication;
  application.setActivationPolicy($.NSApplicationActivationPolicyAccessory);

  const accessory = $.NSView.alloc.initWithFrame($.NSMakeRect(0, 0, 460, 145));
  const opacityValue = valueField(currentOpacity, 0, $.NSMakeRect(382, 112, 48, 20));
  const blurValue = valueField(currentBlur, 1, $.NSMakeRect(382, 45, 48, 20));
  const opacitySlider = slider(
    currentOpacity,
    100,
    11,
    $.NSMakeRect(0, 75, 460, 30),
    "阅读区不透明度",
    opacityValue,
  );
  const blurSlider = slider(
    currentBlur,
    40,
    9,
    $.NSMakeRect(0, 8, 460, 30),
    "阅读区磨砂模糊强度",
    blurValue,
  );

  [
    label("阅读区不透明度", $.NSMakeRect(0, 112, 250, 20)),
    opacityValue,
    label("%", $.NSMakeRect(434, 112, 24, 20)),
    opacitySlider,
    label("磨砂模糊强度", $.NSMakeRect(0, 45, 250, 20)),
    blurValue,
    label("px", $.NSMakeRect(434, 45, 26, 20)),
    blurSlider,
  ].forEach((view) => accessory.addSubview(view));

  const alert = $.NSAlert.alloc.init;
  alert.messageText = "调整阅读区效果";
  alert.informativeText = "拖动滑杆调整数值，点击“应用”后会立即更新当前皮肤。";
  alert.alertStyle = $.NSAlertStyleInformational;
  alert.accessoryView = accessory;
  alert.addButtonWithTitle("应用");
  alert.addButtonWithTitle("取消");

  application.activateIgnoringOtherApps(true);
  const response = Number(alert.runModal);
  if (response !== Number($.NSAlertFirstButtonReturn)) throw new Error("CANCELLED");

  return `${Math.round(Number(opacitySlider.doubleValue))}\t${Math.round(Number(blurSlider.doubleValue) * 10) / 10}`;
}

function run(argv) {
  const currentOpacity = numericArgument(argv[0], 76, 0, 100);
  const currentBlur = numericArgument(argv[1], 14, 0, 40);
  if (argv[0] === "--self-test") {
    return JSON.stringify({
      title: "调整阅读区效果",
      opacityLabel: "阅读区不透明度",
      blurLabel: "磨砂模糊强度",
      output: `${numericArgument(argv[1], 68, 0, 100)}\t${numericArgument(argv[2], 18, 0, 40)}`,
    });
  }
  return showDialog(currentOpacity, currentBlur);
}
