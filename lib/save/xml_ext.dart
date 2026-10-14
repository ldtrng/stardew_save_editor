import 'package:xml/xml.dart';

const xsiNamespace = 'http://www.w3.org/2001/XMLSchema-instance';

/// Convenience accessors for the .NET XmlSerializer output used by Stardew
/// Valley saves. All edits are done in place on the DOM so that every field we
/// don't understand round-trips untouched.
extension XmlElementExt on XmlElement {
  String get tag => name.local;

  /// First direct child element with [name], or null.
  XmlElement? child(String name) {
    for (final node in children) {
      if (node is XmlElement && node.name.local == name) return node;
    }
    return null;
  }

  Iterable<XmlElement> childrenNamed(String name) =>
      childElements.where((e) => e.name.local == name);

  /// Walks a path of direct children, e.g. `path(['value', 'Friendship'])`.
  XmlElement? path(List<String> names) {
    XmlElement? current = this;
    for (final n in names) {
      current = current?.child(n);
      if (current == null) return null;
    }
    return current;
  }

  /// Returns the child with [name], appending an empty one if it is missing.
  XmlElement ensure(String name) {
    final existing = child(name);
    if (existing != null) return existing;
    final created = XmlElement(XmlName(name));
    children.add(created);
    return created;
  }

  String? get xsiType => getAttribute('xsi:type');
  set xsiType(String? value) {
    if (value == null || value.isEmpty) {
      removeAttribute('xsi:type');
    } else {
      setAttribute('xsi:type', value);
    }
  }

  bool get isNil => getAttribute('xsi:nil') == 'true';

  /// Text of a direct child (null when missing or nil).
  String? str(String name) {
    final c = child(name);
    if (c == null || c.isNil) return null;
    return c.innerText;
  }

  int? integer(String name) {
    final s = str(name);
    return s == null ? null : int.tryParse(s.trim());
  }

  double? number(String name) {
    final s = str(name);
    return s == null ? null : double.tryParse(s.trim());
  }

  bool? boolean(String name) {
    final s = str(name)?.trim();
    if (s == null) return null;
    return s == 'true';
  }

  /// Sets the text of a direct child, creating it when needed and clearing a
  /// nil marker if present.
  void setStr(String name, String value) {
    final c = ensure(name);
    c.removeAttribute('xsi:nil');
    c.children
      ..clear()
      ..add(XmlText(value));
  }

  void setInt(String name, int value) => setStr(name, value.toString());
  void setBool(String name, bool value) => setStr(name, value ? 'true' : 'false');
  void setNum(String name, num value) => setStr(name, _formatNum(value));

  /// Replaces this element's own content with a text node.
  void setOwnText(String value) {
    removeAttribute('xsi:nil');
    children
      ..clear()
      ..add(XmlText(value));
  }

  void removeChild(String name) {
    final c = child(name);
    c?.parent?.children.remove(c);
  }

  /// `<container><string>a</string>...</container>` style lists.
  List<String> stringList(String container, [String itemTag = 'string']) {
    final c = child(container);
    if (c == null) return [];
    return c.childrenNamed(itemTag).map((e) => e.innerText).toList();
  }

  void setStringList(String container, List<String> values,
      [String itemTag = 'string']) {
    final c = ensure(container);
    c.children.clear();
    for (final v in values) {
      c.children.add(XmlElement(XmlName(itemTag), [], [XmlText(v)]));
    }
  }

  List<int> intList(String container) => stringList(container, 'int')
      .map((s) => int.tryParse(s.trim()) ?? 0)
      .toList();

  void setIntList(String container, List<int> values) =>
      setStringList(container, values.map((e) => e.toString()).toList(), 'int');
}

String _formatNum(num value) {
  if (value is int) return value.toString();
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}

/// Builds an element tree from a simple nested description. Maps become child
/// elements in insertion order, lists repeat the same tag, nulls become
/// `xsi:nil` elements. Keys starting with `@` are attributes.
XmlElement buildElement(String name, Object? value) {
  final el = XmlElement(XmlName(name));
  _fill(el, value);
  return el;
}

void _fill(XmlElement el, Object? value) {
  if (value == null) {
    el.setAttribute('xsi:nil', 'true');
  } else if (value is Map<String, Object?>) {
    value.forEach((k, v) {
      if (k.startsWith('@')) {
        if (v != null) el.setAttribute(k.substring(1), v.toString());
      } else if (v is List) {
        for (final entry in v) {
          el.children.add(buildElement(k, entry));
        }
      } else {
        el.children.add(buildElement(k, v));
      }
    });
  } else if (value is bool) {
    el.children.add(XmlText(value ? 'true' : 'false'));
  } else if (value is num) {
    el.children.add(XmlText(_formatNum(value)));
  } else if (value is XmlElement) {
    el.children.addAll(value.children.map((c) => c.copy()));
  } else {
    final s = value.toString();
    if (s.isNotEmpty) el.children.add(XmlText(s));
  }
}

/// Serializes like .NET's XmlSerializer: `<tag />` for empty elements and
/// `&`, `<`, `>` escaped in text.
class SdvXmlWriter extends XmlWriter {
  SdvXmlWriter(super.buffer);

  static String write(XmlNode node) {
    final sb = StringBuffer();
    SdvXmlWriter(sb).visit(node);
    return sb.toString();
  }

  @override
  void visitElement(XmlElement node) {
    buffer.write('<');
    visit(node.name);
    writeAttributes(node);
    if (node.children.isEmpty && node.isSelfClosing) {
      buffer.write(' />');
    } else {
      buffer.write('>');
      writeIterable(node.children);
      buffer.write('</');
      visit(node.name);
      buffer.write('>');
    }
  }

  @override
  void visitText(XmlText node) {
    buffer.write(node.value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;'));
  }
}
