/* @ds-bundle: {"format":4,"namespace":"AppleIOSDesignSystem_d4c657","components":[{"name":"Button","sourcePath":"components/actions/Button.jsx"},{"name":"ListItem","sourcePath":"components/content/ListItem.jsx"},{"name":"Checkbox","sourcePath":"components/controls/Checkbox.jsx"},{"name":"Chip","sourcePath":"components/controls/Chip.jsx"},{"name":"PasswordInput","sourcePath":"components/controls/PasswordInput.jsx"},{"name":"PinCodeInput","sourcePath":"components/controls/PinCodeInput.jsx"},{"name":"Radio","sourcePath":"components/controls/Radio.jsx"},{"name":"Switch","sourcePath":"components/controls/Switch.jsx"},{"name":"TextArea","sourcePath":"components/controls/TextArea.jsx"},{"name":"TextInput","sourcePath":"components/controls/TextInput.jsx"},{"name":"Alert","sourcePath":"components/dialogs/Alert.jsx"},{"name":"Badge","sourcePath":"components/indicators/Badge.jsx"},{"name":"Tag","sourcePath":"components/indicators/Tag.jsx"},{"name":"Card","sourcePath":"components/layout/Card.jsx"},{"name":"Divider","sourcePath":"components/layout/Divider.jsx"},{"name":"Link","sourcePath":"components/navigation/Link.jsx"},{"name":"TabBar","sourcePath":"components/navigation/TabBar.jsx"},{"name":"ToolBar","sourcePath":"components/navigation/ToolBar.jsx"}],"sourceHashes":{"components/actions/Button.jsx":"c02fa8343b0f","components/content/ListItem.jsx":"1492448b7ada","components/controls/Checkbox.jsx":"cbc93dc25cad","components/controls/Chip.jsx":"221b5dbc8bf9","components/controls/PasswordInput.jsx":"7daee74bdc7e","components/controls/PinCodeInput.jsx":"e5c02018797a","components/controls/Radio.jsx":"e0cd99880817","components/controls/Switch.jsx":"124340f640d8","components/controls/TextArea.jsx":"7e1cc925d8b6","components/controls/TextInput.jsx":"4f9317aa22dd","components/dialogs/Alert.jsx":"470635066f22","components/indicators/Badge.jsx":"58e647c6e2d8","components/indicators/Tag.jsx":"d0623df2aa75","components/layout/Card.jsx":"9377beaecd78","components/layout/Divider.jsx":"be455bd056d4","components/navigation/Link.jsx":"124c12c84a32","components/navigation/TabBar.jsx":"3fda3ef83323","components/navigation/ToolBar.jsx":"da9abd10e4f4","ui_kits/store-app/Account.jsx":"90208585c72f","ui_kits/store-app/Home.jsx":"2b1cad29ea2a","ui_kits/store-app/ProductDetail.jsx":"8c400a219ae9"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.AppleIOSDesignSystem_d4c657 = window.AppleIOSDesignSystem_d4c657 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/actions/Button.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const base = {
  fontFamily: 'var(--font-text)',
  border: 'none',
  cursor: 'pointer',
  display: 'inline-flex',
  alignItems: 'center',
  justifyContent: 'center',
  gap: '8px',
  transition: 'transform 0.1s ease'
};
const variants = {
  primary: {
    background: 'var(--color-primary)',
    color: 'var(--color-on-primary)',
    fontSize: 'var(--type-body-size)',
    fontWeight: 'var(--type-body-weight)',
    letterSpacing: 'var(--type-body-ls)',
    borderRadius: 'var(--radius-pill)',
    padding: '11px 22px'
  },
  secondaryPill: {
    background: 'transparent',
    color: 'var(--color-primary)',
    fontSize: 'var(--type-body-size)',
    borderRadius: 'var(--radius-pill)',
    padding: '10px 21px',
    border: '1px solid var(--color-primary)'
  },
  darkUtility: {
    background: 'var(--ink-1)',
    color: 'var(--color-text-on-dark)',
    fontSize: 'var(--type-button-utility-size)',
    letterSpacing: 'var(--type-button-utility-ls)',
    borderRadius: 'var(--radius-sm)',
    padding: '8px 15px'
  },
  pearlCapsule: {
    background: 'var(--color-surface-pearl)',
    color: 'var(--color-text-muted-80)',
    fontSize: 'var(--type-caption-size)',
    borderRadius: 'var(--radius-md)',
    padding: '8px 14px',
    border: '3px solid var(--divider-soft, #f0f0f0)'
  },
  storeHero: {
    background: 'var(--color-primary)',
    color: 'var(--color-on-primary)',
    fontSize: 'var(--type-button-large-size)',
    fontWeight: 'var(--type-button-large-weight)',
    borderRadius: 'var(--radius-pill)',
    padding: '14px 28px'
  },
  iconCircular: {
    background: 'var(--color-chip-translucent)',
    color: 'var(--ink-1)',
    borderRadius: 'var(--radius-full)',
    width: 44,
    height: 44,
    padding: 0
  },
  textLink: {
    background: 'transparent',
    color: 'var(--color-primary)',
    fontSize: 'var(--type-body-size)',
    padding: 0
  }
};

/** Apple-style action control. Primary/secondary pills, dark utility rects, pearl capsule, hero, circular icon button, and plain text link. */
function Button({
  variant = 'primary',
  onDark = false,
  disabled = false,
  children,
  icon,
  style,
  ...rest
}) {
  const v = variants[variant] || variants.primary;
  const color = onDark && variant === 'textLink' ? 'var(--color-primary-on-dark)' : v.color;
  return /*#__PURE__*/React.createElement("button", _extends({}, rest, {
    disabled: disabled,
    style: {
      ...base,
      ...v,
      color,
      opacity: disabled ? 0.48 : 1,
      cursor: disabled ? 'default' : 'pointer',
      ...style
    },
    onMouseDown: e => {
      e.currentTarget.style.transform = 'scale(0.95)';
    },
    onMouseUp: e => {
      e.currentTarget.style.transform = 'scale(1)';
    },
    onMouseLeave: e => {
      e.currentTarget.style.transform = 'scale(1)';
    }
  }), icon, children);
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/actions/Button.jsx", error: String((e && e.message) || e) }); }

// components/content/ListItem.jsx
try { (() => {
/** Simple content row (BulletList family) — used for spec lists, settings rows, and footer link lists. */
function ListItem({
  label,
  value,
  chevron = false,
  dense = false,
  onClick
}) {
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClick,
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: dense ? '8px 0' : '14px 0',
      fontFamily: 'var(--font-text)',
      fontSize: dense ? 'var(--type-dense-link-size)' : 'var(--type-body-size)',
      lineHeight: dense ? 'var(--type-dense-link-lh)' : 'var(--type-body-lh)',
      color: 'var(--color-text)',
      cursor: onClick ? 'pointer' : 'default'
    }
  }, /*#__PURE__*/React.createElement("span", null, label), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 6,
      color: 'var(--color-text-muted-48)'
    }
  }, value, chevron && /*#__PURE__*/React.createElement("span", null, "\u203A")));
}
Object.assign(__ds_scope, { ListItem });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/content/ListItem.jsx", error: String((e && e.message) || e) }); }

// components/controls/Checkbox.jsx
try { (() => {
const box = {
  width: 22,
  height: 22,
  borderRadius: 6,
  border: '1.5px solid var(--color-border-hairline)',
  display: 'inline-flex',
  alignItems: 'center',
  justifyContent: 'center',
  flexShrink: 0,
  transition: 'transform 0.1s ease'
};

/** iOS-style checkbox. Use bare for a control, or `variant="item"` for a labeled row (CheckboxItem), and wrap several with `variant="picker"` styling for a CheckboxPicker list. */
function Checkbox({
  checked = false,
  label,
  helper,
  disabled = false,
  onChange,
  variant = 'control'
}) {
  const control = /*#__PURE__*/React.createElement("span", {
    role: "checkbox",
    "aria-checked": checked,
    "aria-disabled": disabled,
    onClick: () => !disabled && onChange && onChange(!checked),
    style: {
      ...box,
      background: checked ? 'var(--color-primary)' : 'var(--color-surface-canvas)',
      borderColor: checked ? 'var(--color-primary)' : 'var(--color-border-hairline)',
      opacity: disabled ? 0.4 : 1,
      cursor: disabled ? 'default' : 'pointer'
    }
  }, checked && /*#__PURE__*/React.createElement("span", {
    style: {
      color: '#fff',
      fontSize: 14,
      lineHeight: 1
    }
  }, "\u2713"));
  if (variant === 'control') return control;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'flex-start',
      gap: 12,
      padding: '10px 0',
      fontFamily: 'var(--font-text)'
    }
  }, control, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--type-body-size)',
      color: 'var(--color-text)'
    }
  }, label), helper && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--type-caption-size)',
      color: 'var(--color-text-muted-48)'
    }
  }, helper)));
}
Object.assign(__ds_scope, { Checkbox });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/controls/Checkbox.jsx", error: String((e && e.message) || e) }); }

// components/controls/Chip.jsx
try { (() => {
/** Pill-shaped tappable cell — configurator option chip. Covers Chip Filter/Picker/Suggestion families via `selected`/`removable`. */
function Chip({
  label,
  selected = false,
  removable = false,
  onClick,
  onRemove
}) {
  return /*#__PURE__*/React.createElement("span", {
    onClick: onClick,
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6,
      background: 'var(--color-surface-canvas)',
      color: 'var(--color-text)',
      fontFamily: 'var(--font-text)',
      fontSize: 'var(--type-caption-size)',
      borderRadius: 'var(--radius-pill)',
      padding: '12px 16px',
      border: selected ? '2px solid var(--color-primary-focus)' : '1px solid var(--color-border-hairline)',
      cursor: onClick ? 'pointer' : 'default'
    }
  }, label, removable && /*#__PURE__*/React.createElement("span", {
    onClick: e => {
      e.stopPropagation();
      onRemove && onRemove();
    },
    style: {
      color: 'var(--color-text-muted-48)'
    }
  }, "\xD7"));
}
Object.assign(__ds_scope, { Chip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/controls/Chip.jsx", error: String((e && e.message) || e) }); }

// components/controls/PinCodeInput.jsx
try { (() => {
/** Segmented one-digit-per-box code entry (PinCodeInput family) — used for 2FA / verification codes. */
function PinCodeInput({
  length = 6,
  values = [],
  onChange
}) {
  const cells = Array.from({
    length
  }, (_, i) => values[i] || '');
  const setCell = (i, v) => {
    const next = [...cells];
    next[i] = v.slice(-1);
    onChange && onChange(next);
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8
    }
  }, cells.map((v, i) => /*#__PURE__*/React.createElement("input", {
    key: i,
    value: v,
    onChange: e => setCell(i, e.target.value),
    maxLength: 1,
    style: {
      width: 44,
      height: 52,
      textAlign: 'center',
      border: '1px solid var(--color-border-soft)',
      borderRadius: 'var(--radius-sm)',
      fontSize: 20,
      fontFamily: 'var(--font-text)',
      color: 'var(--color-text)',
      outline: 'none'
    }
  })));
}
Object.assign(__ds_scope, { PinCodeInput });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/controls/PinCodeInput.jsx", error: String((e && e.message) || e) }); }

// components/controls/Radio.jsx
try { (() => {
/** iOS-style radio button. Bare control (Radio), or `variant="item"` for a labeled row — group several to build a RadioPicker list. */
function Radio({
  selected = false,
  label,
  helper,
  disabled = false,
  onSelect,
  variant = 'control'
}) {
  const control = /*#__PURE__*/React.createElement("span", {
    role: "radio",
    "aria-checked": selected,
    onClick: () => !disabled && onSelect && onSelect(),
    style: {
      width: 22,
      height: 22,
      borderRadius: '50%',
      border: `1.5px solid ${selected ? 'var(--color-primary)' : 'var(--color-border-hairline)'}`,
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      flexShrink: 0,
      opacity: disabled ? 0.4 : 1,
      cursor: disabled ? 'default' : 'pointer'
    }
  }, selected && /*#__PURE__*/React.createElement("span", {
    style: {
      width: 11,
      height: 11,
      borderRadius: '50%',
      background: 'var(--color-primary)'
    }
  }));
  if (variant === 'control') return control;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'flex-start',
      gap: 12,
      padding: '10px 0',
      fontFamily: 'var(--font-text)'
    }
  }, control, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--type-body-size)',
      color: 'var(--color-text)'
    }
  }, label), helper && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--type-caption-size)',
      color: 'var(--color-text-muted-48)'
    }
  }, helper)));
}
Object.assign(__ds_scope, { Radio });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/controls/Radio.jsx", error: String((e && e.message) || e) }); }

// components/controls/Switch.jsx
try { (() => {
/** iOS-style toggle switch (Switch family). */
function Switch({
  on = false,
  disabled = false,
  onChange,
  label
}) {
  const track = /*#__PURE__*/React.createElement("span", {
    role: "switch",
    "aria-checked": on,
    onClick: () => !disabled && onChange && onChange(!on),
    style: {
      width: 51,
      height: 31,
      borderRadius: 999,
      background: on ? 'var(--color-success)' : '#e9e9eb',
      display: 'inline-flex',
      alignItems: 'center',
      padding: 2,
      boxSizing: 'border-box',
      cursor: disabled ? 'default' : 'pointer',
      opacity: disabled ? 0.4 : 1,
      transition: 'background 0.2s ease'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 27,
      height: 27,
      borderRadius: '50%',
      background: '#fff',
      boxShadow: '0 3px 8px rgba(0,0,0,0.18)',
      transform: on ? 'translateX(20px)' : 'translateX(0)',
      transition: 'transform 0.2s ease'
    }
  }));
  if (!label) return track;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      gap: 12,
      fontFamily: 'var(--font-text)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 'var(--type-body-size)',
      color: 'var(--color-text)'
    }
  }, label), track);
}
Object.assign(__ds_scope, { Switch });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/controls/Switch.jsx", error: String((e && e.message) || e) }); }

// components/controls/TextArea.jsx
try { (() => {
/** Multi-line text field (TextArea family) — same chrome as TextInput standard variant. */
function TextArea({
  value,
  onChange,
  placeholder,
  label,
  rows = 4,
  error
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-text)'
    }
  }, label && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--type-caption-strong-size)',
      fontWeight: 'var(--type-caption-strong-weight)',
      color: 'var(--color-text)',
      marginBottom: 6
    }
  }, label), /*#__PURE__*/React.createElement("textarea", {
    value: value,
    onChange: e => onChange && onChange(e.target.value),
    placeholder: placeholder,
    rows: rows,
    style: {
      width: '100%',
      boxSizing: 'border-box',
      resize: 'vertical',
      border: `1px solid ${error ? 'var(--color-error)' : 'var(--color-border-soft)'}`,
      borderRadius: 'var(--radius-sm)',
      padding: '12px 14px',
      fontSize: 'var(--type-body-size)',
      color: 'var(--color-text)',
      fontFamily: 'var(--font-text)',
      outline: 'none'
    }
  }), error && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--type-caption-size)',
      color: 'var(--color-error)',
      marginTop: 4
    }
  }, error));
}
Object.assign(__ds_scope, { TextArea });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/controls/TextArea.jsx", error: String((e && e.message) || e) }); }

// components/controls/TextInput.jsx
try { (() => {
/** Text field with the Apple search-pill and standard rect variants (TextInput family). */
function TextInput({
  value,
  onChange,
  placeholder,
  variant = 'standard',
  label,
  error,
  icon
}) {
  const pill = variant === 'search';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-text)'
    }
  }, label && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--type-caption-strong-size)',
      fontWeight: 'var(--type-caption-strong-weight)',
      color: 'var(--color-text)',
      marginBottom: 6
    }
  }, label), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8,
      background: 'var(--color-surface-canvas)',
      border: `1px solid ${error ? 'var(--color-error)' : 'var(--color-border-soft)'}`,
      borderRadius: pill ? 'var(--radius-pill)' : 'var(--radius-sm)',
      padding: pill ? '12px 20px' : '11px 14px',
      height: 44,
      boxSizing: 'border-box'
    }
  }, icon || pill && /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--color-text-muted-48)',
      fontSize: 14
    }
  }, "\u2315"), /*#__PURE__*/React.createElement("input", {
    value: value,
    onChange: e => onChange && onChange(e.target.value),
    placeholder: placeholder,
    style: {
      border: 'none',
      outline: 'none',
      flex: 1,
      background: 'transparent',
      fontSize: 'var(--type-body-size)',
      color: 'var(--color-text)',
      letterSpacing: 'var(--type-body-ls)'
    }
  })), error && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--type-caption-size)',
      color: 'var(--color-error)',
      marginTop: 4
    }
  }, error));
}
Object.assign(__ds_scope, { TextInput });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/controls/TextInput.jsx", error: String((e && e.message) || e) }); }

// components/controls/PasswordInput.jsx
try { (() => {
const {
  useState
} = React;
/** Password field with a show/hide reveal toggle (PasswordInput family). */
function PasswordInput({
  value,
  onChange,
  label = 'Password',
  error
}) {
  const [visible, setVisible] = useState(false);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-text)'
    }
  }, label && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--type-caption-strong-size)',
      fontWeight: 'var(--type-caption-strong-weight)',
      color: 'var(--color-text)',
      marginBottom: 6
    }
  }, label), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8,
      background: 'var(--color-surface-canvas)',
      border: `1px solid ${error ? 'var(--color-error)' : 'var(--color-border-soft)'}`,
      borderRadius: 'var(--radius-sm)',
      padding: '11px 14px',
      height: 44,
      boxSizing: 'border-box'
    }
  }, /*#__PURE__*/React.createElement("input", {
    type: visible ? 'text' : 'password',
    value: value,
    onChange: e => onChange && onChange(e.target.value),
    style: {
      border: 'none',
      outline: 'none',
      flex: 1,
      background: 'transparent',
      fontSize: 'var(--type-body-size)',
      color: 'var(--color-text)'
    }
  }), /*#__PURE__*/React.createElement("span", {
    onClick: () => setVisible(!visible),
    style: {
      cursor: 'pointer',
      fontSize: 'var(--type-caption-size)',
      color: 'var(--color-primary)'
    }
  }, visible ? 'Hide' : 'Show')), error && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--type-caption-size)',
      color: 'var(--color-error)',
      marginTop: 4
    }
  }, error));
}
Object.assign(__ds_scope, { PasswordInput });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/controls/PasswordInput.jsx", error: String((e && e.message) || e) }); }

// components/dialogs/Alert.jsx
try { (() => {
/** Alert message. `variant="inline"` for an in-page banner (InlineAlert); `variant="message"` for a centered modal-style AlertMessage. */
function Alert({
  variant = 'inline',
  tone = 'error',
  title,
  message,
  actions
}) {
  const tones = {
    error: {
      bg: '#ffe9e8',
      fg: 'var(--color-error)'
    },
    success: {
      bg: '#e7f8ec',
      fg: 'var(--color-success)'
    },
    info: {
      bg: '#eaf2ff',
      fg: 'var(--color-primary)'
    }
  };
  const t = tones[tone] || tones.info;
  if (variant === 'inline') {
    return /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        alignItems: 'flex-start',
        gap: 10,
        background: t.bg,
        color: t.fg,
        borderRadius: 'var(--radius-sm)',
        padding: '12px 16px',
        fontFamily: 'var(--font-text)'
      }
    }, /*#__PURE__*/React.createElement("div", null, title && /*#__PURE__*/React.createElement("div", {
      style: {
        fontSize: 'var(--type-body-strong-size)',
        fontWeight: 600
      }
    }, title), message && /*#__PURE__*/React.createElement("div", {
      style: {
        fontSize: 'var(--type-caption-size)',
        marginTop: 2
      }
    }, message)));
  }
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: 'var(--color-surface-canvas)',
      borderRadius: 'var(--radius-lg)',
      padding: 'var(--space-lg)',
      maxWidth: 320,
      textAlign: 'center',
      boxShadow: '0 20px 60px rgba(0,0,0,0.2)',
      fontFamily: 'var(--font-text)'
    }
  }, title && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--type-body-strong-size)',
      fontWeight: 600,
      marginBottom: 6
    }
  }, title), message && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--type-caption-size)',
      color: 'var(--color-text-muted-48)',
      marginBottom: 16
    }
  }, message), actions);
}
Object.assign(__ds_scope, { Alert });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/dialogs/Alert.jsx", error: String((e && e.message) || e) }); }

// components/indicators/Badge.jsx
try { (() => {
/** Small status indicator. Covers BadgeStandard (dot), BadgeCount (numeral) and BadgeIcon (glyph) families. */
function Badge({
  variant = 'standard',
  count,
  icon,
  color = 'primary'
}) {
  const bg = color === 'primary' ? 'var(--color-primary)' : color === 'error' ? 'var(--color-error)' : 'var(--color-success)';
  if (variant === 'standard') {
    return /*#__PURE__*/React.createElement("span", {
      style: {
        width: 10,
        height: 10,
        borderRadius: '50%',
        background: bg,
        display: 'inline-block'
      }
    });
  }
  if (variant === 'count') {
    return /*#__PURE__*/React.createElement("span", {
      style: {
        minWidth: 18,
        height: 18,
        padding: '0 5px',
        borderRadius: 999,
        background: bg,
        color: '#fff',
        fontSize: 11,
        fontWeight: 600,
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontFamily: 'var(--font-text)'
      }
    }, count);
  }
  return /*#__PURE__*/React.createElement("span", {
    style: {
      width: 20,
      height: 20,
      borderRadius: '50%',
      background: bg,
      color: '#fff',
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontSize: 12
    }
  }, icon);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/indicators/Badge.jsx", error: String((e && e.message) || e) }); }

// components/indicators/Tag.jsx
try { (() => {
/** Rounded label chip for metadata/status. Covers Tag and InputTag (removable) families. */
function Tag({
  label,
  removable = false,
  onRemove,
  tone = 'neutral'
}) {
  const bg = tone === 'neutral' ? 'var(--color-surface-parchment)' : tone === 'success' ? '#e7f8ec' : '#ffe9e8';
  const fg = tone === 'neutral' ? 'var(--color-text-muted-80)' : tone === 'success' ? 'var(--color-success)' : 'var(--color-error)';
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6,
      background: bg,
      color: fg,
      fontFamily: 'var(--font-text)',
      fontSize: 'var(--type-caption-size)',
      fontWeight: 600,
      borderRadius: 'var(--radius-xs)',
      padding: '4px 10px'
    }
  }, label, removable && /*#__PURE__*/React.createElement("span", {
    onClick: onRemove,
    style: {
      cursor: 'pointer'
    }
  }, "\xD7"));
}
Object.assign(__ds_scope, { Tag });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/indicators/Tag.jsx", error: String((e && e.message) || e) }); }

// components/layout/Card.jsx
try { (() => {
const surfaces = {
  light: {
    bg: 'var(--color-surface-canvas)',
    fg: 'var(--color-text)'
  },
  parchment: {
    bg: 'var(--color-surface-parchment)',
    fg: 'var(--color-text)'
  },
  dark: {
    bg: 'var(--color-surface-tile-1)',
    fg: 'var(--color-text-on-dark)'
  },
  dark2: {
    bg: 'var(--color-surface-tile-2)',
    fg: 'var(--color-text-on-dark)'
  },
  dark3: {
    bg: 'var(--color-surface-tile-3)',
    fg: 'var(--color-text-on-dark)'
  }
};

/**
 * Two shapes: `kind="tile"` is a full-bleed product tile (light/parchment/dark/dark2/dark3);
 * `kind="utility"` is the bordered, rounded store-utility card used in grid layouts.
 */
function Card({
  kind = 'utility',
  surface = 'light',
  eyebrow,
  title,
  subtitle,
  media,
  actions,
  children
}) {
  if (kind === 'tile') {
    const s = surfaces[surface] || surfaces.light;
    return /*#__PURE__*/React.createElement("div", {
      style: {
        background: s.bg,
        color: s.fg,
        textAlign: 'center',
        padding: 'var(--space-section) var(--space-lg)',
        fontFamily: 'var(--font-text)'
      }
    }, eyebrow && /*#__PURE__*/React.createElement("div", {
      style: {
        fontSize: 'var(--type-tagline-size)',
        fontWeight: 'var(--type-tagline-weight)',
        marginBottom: 8
      }
    }, eyebrow), title && /*#__PURE__*/React.createElement("h2", {
      style: {
        fontFamily: 'var(--font-display)',
        fontSize: 'var(--type-display-lg-size)',
        fontWeight: 'var(--type-display-lg-weight)',
        margin: '0 0 12px'
      }
    }, title), subtitle && /*#__PURE__*/React.createElement("p", {
      style: {
        fontSize: 'var(--type-lead-size)',
        fontWeight: 'var(--type-lead-weight)',
        margin: '0 0 24px',
        opacity: 0.85
      }
    }, subtitle), actions && /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        gap: 12,
        justifyContent: 'center',
        marginBottom: 32
      }
    }, actions), media && /*#__PURE__*/React.createElement("div", {
      style: {
        filter: 'drop-shadow(var(--shadow-product))',
        display: 'inline-block'
      }
    }, media), children);
  }
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: 'var(--color-surface-canvas)',
      border: '1px solid var(--color-border-hairline)',
      borderRadius: 'var(--radius-lg)',
      padding: 'var(--space-lg)',
      fontFamily: 'var(--font-text)'
    }
  }, media && /*#__PURE__*/React.createElement("div", {
    style: {
      borderRadius: 'var(--radius-sm)',
      overflow: 'hidden',
      marginBottom: 16
    }
  }, media), title && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--type-body-strong-size)',
      fontWeight: 'var(--type-body-strong-weight)',
      color: 'var(--color-text)'
    }
  }, title), subtitle && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--type-body-size)',
      color: 'var(--color-text)',
      marginTop: 4
    }
  }, subtitle), actions && /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 12
    }
  }, actions), children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/layout/Card.jsx", error: String((e && e.message) || e) }); }

// components/layout/Divider.jsx
try { (() => {
/** Hairline separator (Divider / Dividers family). */
function Divider({
  inset = 0,
  onDark = false
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: 1,
      marginLeft: inset,
      background: onDark ? 'rgba(255,255,255,0.16)' : 'var(--color-border-hairline)'
    }
  });
}
Object.assign(__ds_scope, { Divider });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/layout/Divider.jsx", error: String((e && e.message) || e) }); }

// components/navigation/Link.jsx
try { (() => {
/** Inline text link (Link family), on-light or on-dark. */
function Link({
  href = '#',
  onDark = false,
  children
}) {
  return /*#__PURE__*/React.createElement("a", {
    href: href,
    style: {
      color: onDark ? 'var(--color-primary-on-dark)' : 'var(--color-primary)',
      fontFamily: 'var(--font-text)',
      fontSize: 'var(--type-body-size)',
      textDecoration: 'none'
    },
    onMouseOver: e => e.currentTarget.style.textDecoration = 'underline',
    onMouseOut: e => e.currentTarget.style.textDecoration = 'none'
  }, children);
}
Object.assign(__ds_scope, { Link });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/Link.jsx", error: String((e && e.message) || e) }); }

// components/navigation/TabBar.jsx
try { (() => {
/** Bottom tab bar (TabBar family) for an iOS app shell. */
function TabBar({
  items,
  activeIndex = 0,
  onChange
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      background: 'rgba(245,245,247,0.94)',
      backdropFilter: 'saturate(180%) blur(20px)',
      borderTop: '1px solid var(--color-border-hairline)',
      padding: '8px 0 20px',
      fontFamily: 'var(--font-text)'
    }
  }, items.map((item, i) => /*#__PURE__*/React.createElement("div", {
    key: item.label,
    onClick: () => onChange && onChange(i),
    style: {
      flex: 1,
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      gap: 3,
      color: i === activeIndex ? 'var(--color-primary)' : 'var(--color-text-muted-48)',
      cursor: 'pointer'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 22,
      lineHeight: 1
    }
  }, item.icon), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 10,
      fontWeight: 500
    }
  }, item.label))));
}
Object.assign(__ds_scope, { TabBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/TabBar.jsx", error: String((e && e.message) || e) }); }

// components/navigation/ToolBar.jsx
try { (() => {
/**
 * Top/bottom chrome bars. Covers ToolBarTop (global-nav / sub-nav-frosted) and
 * ToolBarBottom (floating sticky bar) families via `variant`.
 */
function ToolBar({
  variant = 'globalNav',
  left,
  center,
  right
}) {
  const styles = {
    globalNav: {
      background: 'var(--color-surface-black)',
      color: 'var(--color-text-on-dark)',
      height: 44,
      fontSize: 'var(--type-nav-link-size)'
    },
    subNav: {
      background: 'rgba(245,245,247,0.8)',
      backdropFilter: 'saturate(180%) blur(20px)',
      color: 'var(--color-text)',
      height: 52,
      fontSize: 'var(--type-tagline-size)',
      fontWeight: 600
    },
    stickyBottom: {
      background: 'rgba(245,245,247,0.8)',
      backdropFilter: 'saturate(180%) blur(20px)',
      color: 'var(--color-text)',
      height: 64,
      fontSize: 'var(--type-body-size)'
    }
  };
  const s = styles[variant] || styles.globalNav;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      ...s,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '0 24px',
      fontFamily: 'var(--font-text)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 20
    }
  }, left), /*#__PURE__*/React.createElement("div", null, center), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 16
    }
  }, right));
}
Object.assign(__ds_scope, { ToolBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/ToolBar.jsx", error: String((e && e.message) || e) }); }

// ui_kits/store-app/Account.jsx
try { (() => {
// Account screen — Settings-style list rows, using ListItem/Divider/Switch, mirrors iOS Settings conventions.
function Account() {
  const {
    ToolBar,
    ListItem,
    Divider,
    Switch,
    Button
  } = window.AppleIOSDesignSystem_d4c657;
  const [notifs, setNotifs] = React.useState(true);
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(ToolBar, {
    variant: "subNav",
    left: /*#__PURE__*/React.createElement("span", null, "Account"),
    right: null
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '24px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-text)',
      fontWeight: 600,
      fontSize: 'var(--type-caption-strong-size)',
      color: 'var(--color-text-muted-48)',
      marginBottom: 8
    }
  }, "APPLE ID"), /*#__PURE__*/React.createElement(ListItem, {
    label: "Name, Phone, Email",
    chevron: true,
    onClick: () => {}
  }), /*#__PURE__*/React.createElement(Divider, null), /*#__PURE__*/React.createElement(ListItem, {
    label: "iCloud",
    value: "4.8GB of 5GB Used",
    chevron: true,
    onClick: () => {}
  }), /*#__PURE__*/React.createElement(Divider, null), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 24
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-text)',
      fontWeight: 600,
      fontSize: 'var(--type-caption-strong-size)',
      color: 'var(--color-text-muted-48)',
      marginBottom: 8
    }
  }, "PREFERENCES"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '14px 0'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-text)',
      fontSize: 'var(--type-body-size)'
    }
  }, "Notifications"), /*#__PURE__*/React.createElement(Switch, {
    on: notifs,
    onChange: setNotifs
  })), /*#__PURE__*/React.createElement(Divider, null), /*#__PURE__*/React.createElement(ListItem, {
    label: "Payment & Shipping",
    chevron: true,
    onClick: () => {}
  }), /*#__PURE__*/React.createElement(Divider, null), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 32
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "textLink"
  }, "Sign Out"))));
}
window.Account = Account;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/store-app/Account.jsx", error: String((e && e.message) || e) }); }

// ui_kits/store-app/Home.jsx
try { (() => {
// Home screen — feed of alternating product tiles (light/parchment/dark), mirrors apple.com homepage rhythm.
function Home({
  onOpenProduct
}) {
  const {
    Card,
    Button,
    ToolBar
  } = window.AppleIOSDesignSystem_d4c657;
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(ToolBar, {
    variant: "subNav",
    left: /*#__PURE__*/React.createElement("span", null, "Store"),
    right: /*#__PURE__*/React.createElement(Button, {
      variant: "darkUtility"
    }, "Sign In")
  }), /*#__PURE__*/React.createElement(Card, {
    kind: "tile",
    surface: "light",
    eyebrow: "iPhone 17 Pro",
    title: "Titanium. So strong. So light. So Pro.",
    subtitle: "From $999 or $41.62/mo. for 24 mo.",
    actions: /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Button, {
      variant: "primary",
      onClick: () => onOpenProduct('iphone')
    }, "Learn more"), /*#__PURE__*/React.createElement(Button, {
      variant: "secondaryPill",
      onClick: () => onOpenProduct('iphone')
    }, "Buy")),
    media: /*#__PURE__*/React.createElement("div", {
      style: {
        width: 220,
        height: 220,
        borderRadius: 16,
        background: 'linear-gradient(135deg,#3a3a3c,#1d1d1f)'
      }
    })
  }), /*#__PURE__*/React.createElement(Card, {
    kind: "tile",
    surface: "dark",
    eyebrow: "AirPods Pro 3",
    title: "Adaptive Audio. Now playing everywhere.",
    subtitle: "From $249",
    actions: /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Button, {
      variant: "primary"
    }, "Learn more"), /*#__PURE__*/React.createElement(Button, {
      variant: "textLink",
      onDark: true
    }, "Buy")),
    media: /*#__PURE__*/React.createElement("div", {
      style: {
        width: 160,
        height: 160,
        borderRadius: '50%',
        background: '#e6e6e8'
      }
    })
  }), /*#__PURE__*/React.createElement(Card, {
    kind: "tile",
    surface: "parchment",
    eyebrow: "Apple Watch Series 11",
    title: "Smarter. Brighter. Mightier.",
    subtitle: "From $399",
    actions: /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Button, {
      variant: "primary"
    }, "Learn more"), /*#__PURE__*/React.createElement(Button, {
      variant: "secondaryPill"
    }, "Buy")),
    media: /*#__PURE__*/React.createElement("div", {
      style: {
        width: 140,
        height: 180,
        borderRadius: 28,
        background: '#1d1d1f'
      }
    })
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '32px 24px',
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: 16,
      background: '#fff'
    }
  }, [{
    name: 'MagSafe Charger',
    price: '$39'
  }, {
    name: 'Smart Folio',
    price: '$79'
  }].map(p => /*#__PURE__*/React.createElement(Card, {
    key: p.name,
    kind: "utility",
    title: p.name,
    subtitle: p.price,
    media: /*#__PURE__*/React.createElement("div", {
      style: {
        background: '#f5f5f7',
        height: 90,
        borderRadius: 8
      }
    }),
    actions: /*#__PURE__*/React.createElement(Button, {
      variant: "textLink"
    }, "Buy")
  }))));
}
window.Home = Home;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/store-app/Home.jsx", error: String((e && e.message) || e) }); }

// ui_kits/store-app/ProductDetail.jsx
try { (() => {
// Product detail / buy screen — configurator chips + floating sticky bar, mirrors the iPhone 17 Pro buy page.
function ProductDetail({
  onBack
}) {
  const {
    Button,
    ToolBar,
    Chip,
    Card
  } = window.AppleIOSDesignSystem_d4c657;
  const [storage, setStorage] = React.useState('256');
  const [color, setColor] = React.useState('black');
  const price = storage === '256' ? 1099 : storage === '512' ? 1299 : 999;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      paddingBottom: 84
    }
  }, /*#__PURE__*/React.createElement(ToolBar, {
    variant: "subNav",
    left: /*#__PURE__*/React.createElement("span", {
      onClick: onBack,
      style: {
        cursor: 'pointer'
      }
    }, "\u2039 iPhone"),
    right: null
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      background: '#1d1d1f',
      textAlign: 'center',
      padding: '48px 24px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 180,
      height: 220,
      margin: '0 auto',
      borderRadius: 20,
      background: 'linear-gradient(135deg,#3a3a3c,#111)',
      filter: 'drop-shadow(var(--shadow-product))'
    }
  }), /*#__PURE__*/React.createElement("h2", {
    style: {
      fontFamily: 'var(--font-display)',
      color: '#fff',
      fontSize: 'var(--type-display-lg-size)',
      fontWeight: 600,
      margin: '24px 0 4px'
    }
  }, "iPhone 17 Pro"), /*#__PURE__*/React.createElement("p", {
    style: {
      color: '#cccccc',
      fontFamily: 'var(--font-text)',
      fontSize: 'var(--type-body-size)'
    }
  }, "Titanium. So strong. So light. So Pro.")), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: 24
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-text)',
      fontWeight: 600,
      fontSize: 'var(--type-body-strong-size)',
      marginBottom: 12
    }
  }, "Storage"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10,
      flexWrap: 'wrap',
      marginBottom: 24
    }
  }, /*#__PURE__*/React.createElement(Chip, {
    label: "128GB",
    selected: storage === '128',
    onClick: () => setStorage('128')
  }), /*#__PURE__*/React.createElement(Chip, {
    label: "256GB \xB7 +$100",
    selected: storage === '256',
    onClick: () => setStorage('256')
  }), /*#__PURE__*/React.createElement(Chip, {
    label: "512GB \xB7 +$300",
    selected: storage === '512',
    onClick: () => setStorage('512')
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-text)',
      fontWeight: 600,
      fontSize: 'var(--type-body-strong-size)',
      marginBottom: 12
    }
  }, "Finish"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10,
      flexWrap: 'wrap'
    }
  }, /*#__PURE__*/React.createElement(Chip, {
    label: "Space Black",
    selected: color === 'black',
    onClick: () => setColor('black')
  }), /*#__PURE__*/React.createElement(Chip, {
    label: "Silver",
    selected: color === 'silver',
    onClick: () => setColor('silver')
  }), /*#__PURE__*/React.createElement(Chip, {
    label: "Titanium",
    selected: color === 'titanium',
    onClick: () => setColor('titanium')
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'fixed',
      bottom: 0,
      left: 0,
      right: 0
    }
  }, /*#__PURE__*/React.createElement(ToolBar, {
    variant: "stickyBottom",
    left: /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: 'var(--font-text)'
      }
    }, "From $", price),
    right: /*#__PURE__*/React.createElement(Button, {
      variant: "primary"
    }, "Add to Bag")
  })));
}
window.ProductDetail = ProductDetail;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/store-app/ProductDetail.jsx", error: String((e && e.message) || e) }); }

__ds_ns.Button = __ds_scope.Button;

__ds_ns.ListItem = __ds_scope.ListItem;

__ds_ns.Checkbox = __ds_scope.Checkbox;

__ds_ns.Chip = __ds_scope.Chip;

__ds_ns.PasswordInput = __ds_scope.PasswordInput;

__ds_ns.PinCodeInput = __ds_scope.PinCodeInput;

__ds_ns.Radio = __ds_scope.Radio;

__ds_ns.Switch = __ds_scope.Switch;

__ds_ns.TextArea = __ds_scope.TextArea;

__ds_ns.TextInput = __ds_scope.TextInput;

__ds_ns.Alert = __ds_scope.Alert;

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.Tag = __ds_scope.Tag;

__ds_ns.Card = __ds_scope.Card;

__ds_ns.Divider = __ds_scope.Divider;

__ds_ns.Link = __ds_scope.Link;

__ds_ns.TabBar = __ds_scope.TabBar;

__ds_ns.ToolBar = __ds_scope.ToolBar;

})();
