// Google Gemini embeddings — embedContent / batchEmbedContents
// patches/03-fix-gemini-embedding.sh — try v1 first, fall back to v1beta
const BASE_V1 = "https://generativelanguage.googleapis.com/v1";
const BASE_V1BETA = "https://generativelanguage.googleapis.com/v1beta";

// Gemini embedding models that are known to be available on v1 (GA).
// Anything not in this set falls back to v1beta for compatibility.
const V1_MODELS = new Set([
  "gemini-embedding-001",
  "gemini-embedding-2-preview",
  "text-embedding-005",
]);

function pickBase(model) {
  const bare = model.startsWith("models/") ? model.slice(7) : model;
  return V1_MODELS.has(bare) ? BASE_V1 : BASE_V1BETA;
}

function modelPath(model) {
  return model.startsWith("models/") ? model : `models/${model}`;
}

export default {
  buildUrl: (model, creds, { input } = {}) => {
    const apiKey = creds.apiKey || creds.accessToken;
    const path = modelPath(model);
    const op = Array.isArray(input) ? "batchEmbedContents" : "embedContent";
    const base = pickBase(model);
    return `${base}/${path}:${op}?key=${encodeURIComponent(apiKey)}`;
  },
  buildHeaders: () => ({ "Content-Type": "application/json" }),
  buildBody: (model, { input }) => {
    const m = modelPath(model);
    if (Array.isArray(input)) {
      return { requests: input.map((text) => ({ model: m, content: { parts: [{ text: String(text) }] } })) };
    }
    return { model: m, content: { parts: [{ text: String(input) }] } };
  },
  normalize: (responseBody, model) => {
    if (responseBody.object === "list" && Array.isArray(responseBody.data)) return responseBody;
    let items = [];
    if (Array.isArray(responseBody.embeddings)) {
      items = responseBody.embeddings.map((emb, idx) => ({
        object: "embedding",
        index: idx,
        embedding: emb.values || [],
      }));
    } else if (responseBody.embedding?.values) {
      items = [{ object: "embedding", index: 0, embedding: responseBody.embedding.values }];
    }
    return {
      object: "list",
      data: items,
      model,
      usage: { prompt_tokens: 0, total_tokens: 0 },
    };
  },
};
