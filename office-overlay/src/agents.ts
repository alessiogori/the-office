export type AgentStatus = "WORKING" | "IDLE" | "STANDBY";

export interface AgentState {
  status: AgentStatus;
  task: string;
  ts: string;
}

export type StatusMap = Record<string, AgentState>;

export interface AgentDef {
  id: string;
  name: string;
  role: string;
  color: number;
}

export const AGENTS: AgentDef[] = [
  { id: "alessio",    name: "Alessio",    role: "CEO",  color: 0xf5b400 },
  { id: "stefano",    name: "Stefano",    role: "Eng",  color: 0x4a90e2 },
  { id: "walter",     name: "Walter",     role: "Prod", color: 0x9b59b6 },
  { id: "veronica",   name: "Veronica",   role: "Mkt",  color: 0xe74c3c },
  { id: "alessandra", name: "Alessandra", role: "UX",   color: 0x1abc9c },
  { id: "marwen",     name: "Marwen",     role: "QA",   color: 0x2ecc71 },
];

export const STATUS_COLORS: Record<AgentStatus, number> = {
  WORKING: 0x2ecc71,
  IDLE: 0xf1c40f,
  STANDBY: 0x7f8c8d,
};
