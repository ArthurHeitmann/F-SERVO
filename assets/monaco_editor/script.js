
(() => {
let wordWrap = true;

let lang;
let windowId;
window.addEventListener("load", () => {
	const params = new URLSearchParams(window.location.search);
	lang = params.get("lang") || null;
	const theme = params.get("theme") || "vs-dark";
	windowId = params.get("windowId") || null;

	require.config({ paths: { vs: "./node_modules/monaco-editor/min/vs" }});
	require(["vs/editor/editor.main"], function () {
		const textEditor = monaco.editor.create(document.getElementById("container"), {
			language: lang,
			theme: theme,
			automaticLayout: true,
			smoothScrolling: true,
			wordWrap: wordWrap ? "on" : "off",
		});
		textEditor.getModel().onDidChangeContent(throttle(onModelContentChange, 200));
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
	if (lang === "xml") {
		const validation = XMLValidator.validate(value);
		if (validation !== true && validation?.err) {
			const marker = {
				startLineNumber: validation.err.line,
				startColumn: validation.err.col,
				endLineNumber: validation.err.line,
				endColumn: validation.err.col,
				message: validation.err.msg,
				severity: monaco.MarkerSeverity.Error,
			}
			monaco.editor.setModelMarkers(model, "xml", [marker]);
		}
		else {
			monaco.editor.setModelMarkers(model, "xml", []);
		}
	}
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
	console.log("postMessage", message);
	if (window.chrome?.webview)
		window.chrome.webview.postMessage(message);
	else if (window.parent)
		window.parent.postMessage({
			...message,
			windowId: windowId,
		}, "*");
	else
		console.warn("No postMessage method available", message);
		
}

(window.chrome?.webview ?? window.parent)?.addEventListener("message", (e) => {
	let message = e.data;
	if (typeof message === "string") {
		try {
			message = JSON.parse(message);
		} catch (err) {
			return;
		}
	}
	const type = message.type;
	if (message.windowId && windowId && message.windowId !== windowId)
		return;
	switch (type) {
		case null:
		case undefined:
			break;
		case "jumpToLine":
			jumpToLine(message.line);
			break;
		case "setContent":
			window.textEditor.setValue(message.value);
			break;
		default:
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
		});
		return;
	}

	if (e.altKey && e.key === "z") {
		wordWrap = !wordWrap;
		textEditor.updateOptions({
			wordWrap: wordWrap ? "on" : "off",
		});
	}
});

function throttle(func, wait, options = { leading: true, trailing: true}) {
	let context, args, result;
	let timeout = null;
	let previous = 0;
	if (!options) options = {};
	const later = function() {
		previous = options.leading === false ? 0 : Date.now();
		timeout = null;
		result = func.apply(context, args);
		if (!timeout) {
			context = args = null;
		}
	};
	return function() {
		const now = Date.now();
		if (!previous && options.leading === false) previous = now;
		const remaining = wait - (now - previous);
		context = this;
		args = arguments;
		if (remaining <= 0 || remaining > wait) {
			if (timeout) {
				clearTimeout(timeout);
				timeout = null;
			}
			previous = now;
			result = func.apply(context, args);
			if (!timeout) context = args = null;
		} else if (!timeout && options.trailing !== false) {
			timeout = setTimeout(later, remaining);
		}
		return result;
	};
}

})();
