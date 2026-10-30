import type { Field, Values } from "./AdminForm";
import type { Page, Row } from "@/lib/mvp/client";
export type Editor = {
  title: string;
  fields: Field[];
  initial?: Values;
  submit?: string;
  save: (values: Values, key: string) => Promise<void>;
};
export type Actor = {
  authenticated: true;
  userId: string;
  businessId: string;
  assignments: { permission: string; branchId: string | null; role: string }[];
};
export type Workspace = {
  actor: Actor;
  business: Page;
  branches: Page;
  services: Page;
  selectedBranchId: string | null;
  data: Record<string, Page>;
};
export type PortalWrite = (
  op: string,
  id: string | null,
  version: string,
  data: unknown,
  key: string,
  branch?: string | null,
) => Promise<Row>;
