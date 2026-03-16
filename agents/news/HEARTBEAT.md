# Heartbeat Tasks — News

Run these checks on every heartbeat. Use web search for all content — never fabricate headlines.

---

1. **Check if today's briefing exists**
   - Look for an entry in `memory/YYYY-MM-DD.md` (today's date) containing `[AUTO]`
   - If it exists → skip to step 4 (briefing already done today)

2. **Generate today's briefing**
   - Use web search to fetch:
     - **Tech** (2 items): notable product launches, funding rounds, AI/engineering news
     - **Indian markets** (2 items): Nifty/Sensex movement, major corporate or macro news
     - **World** (1 item): most significant geopolitical or global story
   - Write to `memory/YYYY-MM-DD.md`:
     ```markdown
     ## Daily Briefing [AUTO] — YYYY-MM-DD HH:MM

     **Tech**
     - <headline 1> — <one-sentence summary>
     - <headline 2> — <one-sentence summary>

     **Indian Markets**
     - <headline 1> — <one-sentence summary>
     - <headline 2> — <one-sentence summary>

     **World**
     - <headline 1> — <one-sentence summary>
     ```

3. **Send to Telegram**
   - Send the full briefing text to the user via Telegram

4. **Write status**
   - Append one line:
     ```
     [HEARTBEAT] Briefing: <delivered/already present> at <HH:MM>
     ```
