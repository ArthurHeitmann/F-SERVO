import { onMessage } from "./worker_base";

async function postMessage(data) {
	if (self instanceof ServiceWorkerGlobalScope) {
		const clients = await self.clients.matchAll();
		for (const client of clients) {
			client.postMessage(data);
		}
	} else {
		self.postMessage(data);
	}
}

self.addEventListener("message", (e: ExtendableMessageEvent) => {
	onMessage(e.data, postMessage);
});
