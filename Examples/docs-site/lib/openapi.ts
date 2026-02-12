import { createOpenAPI } from "fumadocs-openapi/server";

export const openapi = createOpenAPI({
  proxyUrl: "/api/proxy",
});
