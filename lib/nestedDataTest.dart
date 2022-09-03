import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

var xmlData = XmlDocument.parse("""
  <children>
    <text>Hello</text>
    <text>World</text>
    <children>
      <text>Nested</text>
      <text>Text</text>
      <children>
        <text>More</text>
      </children>
      <children>
        <text>Nested</text>
        <text>Text</text>
        <children>
          <text>More</text>
        </children>
      </children>
    </children>
    <text>World</text>
  </children>
""");
final root = XmlData(xmlData.rootElement);


class XmlData extends ChangeNotifier {
  final XmlElement _root;
  List<XmlData> children = [];

  XmlData(this._root) {
    children = _root.children
      .whereType<XmlElement>()
      .map((child) => XmlData(child)).toList();
  }

  bool get isText => _root.name.local == "text";
  String get text => _root.text;
  set text(String value) {
    _root.innerText = value;
    notifyListeners();
  }
  
  void addChild(XmlData child) {
    children.add(child);
    notifyListeners();
  }

  void removeChild(XmlData child) {
    children.remove(child);
    notifyListeners();
  }

  @override
  void dispose() {
    for (var child in children) {
      child.dispose();
    }
    super.dispose();
  }
}

class XmlDataViewerRoot extends StatelessWidget {
  const XmlDataViewerRoot({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          XmlDataEditor(root, true),
          XmlDataEditor(root, false),
        ],
      )
    );
  }
}

// class XmlDataViewer extends ConsumerWidget {
//   const XmlDataViewer({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     var xmlElement = ref.watch(xmlDataProvider);
//     if (xmlElement.isText) {
//       return ConstrainedBox(
//         constraints: const BoxConstraints(maxWidth: 200),
//         child: TextFormField(
//           textAlign: TextAlign.left,
//           // initial text
//           initialValue: xmlElement.text,
//         ),
//       );
//     }
//     return Padding(
//       padding: const EdgeInsets.only(left: 10),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: xmlElement.children
//           .whereType<XmlElement>()
//           .map((child) {
//             return ProviderScope(
//               overrides: [
//                 xmlDataProvider.overrideWithValue(XmlState(child)),
//               ],
//               child: const XmlDataViewer(),
//             );
//           }).toList(),
//       ),
//     );
//   }
// }


class XmlDataEditor extends StatefulWidget {
  final XmlData element;
  final bool isEditable;

  const XmlDataEditor(this.element, this.isEditable, {Key? key}) : super(key: key);

  @override
  State<XmlDataEditor> createState() => _XmlDataEditorState();
}

class _XmlDataEditorState extends State<XmlDataEditor> {
  void update() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    
    widget.element.addListener(update);
  }

  @override
  void dispose() {
    widget.element.removeListener(update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.element.isText) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: widget.isEditable
          ? TextFormField(
            textAlign: TextAlign.left,
            // initial text
            initialValue: widget.element.text,
            onChanged: (value) {
              widget.element.text = value;
            },
          )
          : Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Text(
              widget.element.text,
              textScaleFactor: 1.4,
            ),
          ),
      );
    }
    List<Widget> children = widget.element.children
          .map((child) {
            return XmlDataEditor(child, widget.isEditable);
          }).toList();
    if (widget.isEditable) {
      children.add(
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            widget.element.addChild(XmlData(XmlElement(XmlName("text"))));
          },
        )
      );
    }


    return Padding(
      padding: const EdgeInsets.only(left: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
