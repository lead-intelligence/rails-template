require "axe/configuration"

module AccessibilityHelper
  AXE_TAGS = %w[wcag2a wcag2aa wcag21a wcag21aa].freeze
  AXE_MAX_TARGETS = 5
  AXE_COLOR_SCHEMES = %w[light dark].freeze
  PHONE_WIDTH = 390

  # The innermost elements that end past the right edge, when the page scrolls sideways.
  WIDE_SCRIPT = <<~JS.freeze
    (function () {
      var root = document.documentElement;
      if (root.scrollWidth <= root.clientWidth) return [];
      var wide = Array.from(document.body.querySelectorAll("*")).filter(function (element) {
        return element.getBoundingClientRect().right > root.clientWidth + 1;
      });
      return wide.filter(function (element) {
        return !wide.some(function (other) { return other !== element && element.contains(other); });
      }).slice(0, 5).map(function (element) {
        var name = element.tagName.toLowerCase();
        if (element.id) name += "#" + element.id;
        if (element.className && element.className.baseVal === undefined) name += "." + element.className.trim().split(/\s+/).join(".");
        return "  " + name + " (ends at " + Math.round(element.getBoundingClientRect().right) + "px)";
      });
    })()
  JS

  AXE_SCRIPT = <<~JS.freeze
    var done = arguments[arguments.length - 1];
    axe.run(document, arguments[0]).then(function (results) {
      done(results.violations.map(function (violation) {
        return {
          id: violation.id,
          impact: violation.impact,
          help: violation.help,
          helpUrl: violation.helpUrl,
          targets: violation.nodes.map(function (node) { return node.target.join(" "); })
        };
      }));
    });
  JS

  def assert_accessible
    inject_axe

    violations = AXE_COLOR_SCHEMES.flat_map do |scheme|
      emulate_color_scheme(scheme)
      audit_page.each { |violation| violation["scheme"] = scheme }
    end

    assert_empty violations, accessibility_failure_message(violations)
  ensure
    emulate_color_scheme(nil)
  end

  # A page must fit a phone: at 390px wide, nothing scrolls sideways.
  def assert_fits_phone
    window = page.current_window
    size = window.size
    window.resize_to(PHONE_WIDTH, size.last)
    wide = page.evaluate_script(WIDE_SCRIPT)
    assert_empty wide, "#{page.current_path} scrolls sideways on a #{PHONE_WIDTH}px phone. It sticks out:\n#{wide.join("\n")}"
  ensure
    window&.resize_to(*size) if size
  end

  private

  def audit_page
    page.evaluate_async_script(AXE_SCRIPT, "runOnly" => { "type" => "tag", "values" => AXE_TAGS })
  end

  def emulate_color_scheme(scheme)
    features = scheme ? [ { name: "prefers-color-scheme", value: scheme } ] : []
    page.driver.browser.page.command("Emulation.setEmulatedMedia", features: features)
  end

  def inject_axe
    return if page.evaluate_script("typeof window.axe === 'object'")

    page.execute_script(Axe::Configuration.instance.jslib)
  end

  def accessibility_failure_message(violations)
    return "" if violations.empty?

    header = "#{violations.size} accessibility #{'violation'.pluralize(violations.size)} on #{page.current_path}:"
    [ header, *violations.map { |violation| accessibility_violation_message(violation) } ].join("\n\n")
  end

  def accessibility_violation_message(violation)
    targets = violation["targets"]
    shown = targets.first(AXE_MAX_TARGETS)
    shown << "(+#{targets.size - AXE_MAX_TARGETS} more)" if targets.size > AXE_MAX_TARGETS

    [
      "  #{violation['id']} (#{violation['impact']}, #{violation['scheme']} theme) — #{violation['help']}",
      "    #{violation['helpUrl']}",
      *shown.map { |target| "    #{target}" }
    ].join("\n")
  end
end
