
window.addEventListener("load", () => {
	const params = new URLSearchParams(window.location.search);
	const lang = params.get("lang") || null;
	const theme = params.get("theme") || "vs-dark";

	require.config({ paths: { vs: "./node_modules/monaco-editor/min/vs" }});
	require(["vs/editor/editor.main"], function () {
		const textEditor = monaco.editor.create(document.getElementById("container"), {
			language: lang,
			theme: theme,
			automaticLayout: true,
			smoothScrolling: true,
		});
		textEditor.getModel().onDidChangeContent(onModelContentChange);
		window.textEditor = textEditor;
		postMessage({ type: "ready" });
	});
});

function onModelContentChange() {
	const model = window.textEditor.getModel();
	const value = model.getValue();
	postMessage({
		type: "change",
		value: value,
	});
}

function jumpToLine(lineNumber) {
	const textEditor = window.textEditor;
	const lineLength = textEditor.getModel().getLineMaxColumn(lineNumber);
	textEditor.revealLineInCenter(lineNumber);
	textEditor.setPosition({ lineNumber: lineNumber, column: 1 });
	textEditor.setSelection({
		startLineNumber: lineNumber,
		startColumn: 1,
		endLineNumber: lineNumber,
		endColumn: lineLength,
	});
	textEditor.focus();
	postMessage({ type: "jumped" });
}

function postMessage(message) {
	window.chrome?.webview?.postMessage(message);
}

window.chrome?.webview?.addEventListener("message", (e) => {
	const message = e.data;
	const type = message.type;
	if (type)
		console.log("Message received", message);
	switch (type) {
		case null:
		case undefined:
			break;
		case "jumpToLine":
			jumpToLine(message.line);
			break;
		default:
			console.warn("Unknown message type", type);
			break;
	}
});

window.addEventListener("keydown", (e) => {
	if (e.ctrlKey && ["s", "w", "tab"].includes(e.key.toLowerCase())) {
		e.preventDefault();
		postMessage({
			type: "keydown",
			event: {
				key: e.key,
				ctrlKey: e.ctrlKey,
				shiftKey: e.shiftKey,
				altKey: e.altKey,
				metaKey: e.metaKey,
			},
		})
	}
});
