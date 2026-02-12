import { generateFiles } from "fumadocs-openapi";

void generateFiles({
  input: ["./openapi/bithuman-api.yaml"],
  output: "./content/docs/api-reference",
  includeDescription: true,
});
