"use client";
import React from "react";
import SmartImage from "@/src/components/SmartImage";

type Totals = { p1: string; p2: string; };
type Player = { name: string; pfpUrl?: string | null; };
type MatchState = {
  status: "OPEN" | "LOCKED" | "SETTLED";
  p1: Player; p2: Player;
  scoreP1?: number; scoreP2?: number;
  totals: Totals;
};

export default function OverlayPage() {
  const [state, setState] = React.useState<MatchState | null>(null);

  React.useEffect(() => {
    let timer: NodeJS.Timeout;
    const tick = async () => {
      try {
        const r = await fetch("/api/matches/current", { cache: "no-store" });
        const j = await r.json();
        setState(j.match);
      } catch {}
      timer = setTimeout(tick, 2000);
    };
    tick();
    return () => clearTimeout(timer);
  }, []);

  if (!state) return <div style={{color:"#fff", padding:20}}>Waiting for match…</div>;

  const totalP1 = Number(state.totals.p1 || "0");
  const totalP2 = Number(state.totals.p2 || "0");
  const sum = totalP1 + totalP2 || 1;
  const leftPct = (totalP1 / sum) * 100;

  return (
    <div style={{fontFamily:"system-ui", color:"#fff", background:"#000", width:"100vw", height:"100vh"}}>
      {/* Ratio bar */}
      <div style={{position:"absolute", top:0, left:0, height:12, width:"100%", background:"#223"}}>
        <div style={{height:"100%", width:`${leftPct}%`, background:"#922"}} />
      </div>

      {/* Names + avatars */}
      <div style={{display:"flex", gap:24, alignItems:"center", justifyContent:"center", height:"100%"}}>
        <div style={{display:"flex", alignItems:"center", gap:12}}>
          <SmartImage src={state.p1.pfpUrl || "/pfp/default.png"} alt="P1" width={64} height={64}/>
          <div style={{fontSize:28}}>{state.p1.name}</div>
        </div>
        <div style={{fontSize:24, opacity:.8}}>
          {state.status} &middot; {state.scoreP1 ?? 0} - {state.scoreP2 ?? 0}
        </div>
        <div style={{display:"flex", alignItems:"center", gap:12}}>
          <div style={{fontSize:28}}>{state.p2.name}</div>
          <SmartImage src={state.p2.pfpUrl || "/pfp/default.png"} alt="P2" width={64} height={64}/>
        </div>
      </div>
    </div>
  );
}
