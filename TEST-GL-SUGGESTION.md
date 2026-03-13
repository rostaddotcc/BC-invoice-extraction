# Testplan: AI GL Account Suggestion

## Förberedelser

1. **Bygg extensionen**
   ```bash
   # I VS Code:
   Ctrl+Shift+B  # eller kör AL: Build
   ```

2. **Publicera till sandbox**
   ```bash
   Ctrl+F5  # eller AL: Publish
   ```

---

## Teststeg

### Test 1: Aktivera AI GL Suggestion

1. Öppna **AI Extraction Setup** (sök i Business Central)
2. Kontrollera att fältet **"Enable AI GL Suggestion"** finns
3. Bocka i **"Enable AI GL Suggestion"**
4. Klicka på **"Refresh Chart of Accounts"** action
5. Verifiera att meddelandet "Chart of accounts refreshed successfully" visas

**Förväntat resultat:** Kontoplanen är nu cachad och redo att skickas till AI

---

### Test 2: Kontrollera att kontoplan skickas till AI

1. Ladda upp en fakturabild via **Batch Upload**
2. Vänta tills processningen är klar (status = "Ready")
3. Öppna fakturan i **Invoice Preview**
4. Kontrollera att raderna har **Type** = "G/L Account" och **No.** är ifyllt

**Förväntat resultat:**
- Om AI kunde matcha beskrivningen → **No.** ska innehålla AI-föreslaget konto
- Om AI inte kunde matcha → **No.** ska innehålla **Default G/L Account** från setup

---

### Test 3: Verifiera fallback till default

1. Gå till **AI Extraction Setup**
2. Sätt **Default G/L Account** till ett specifikt konto (t.ex. "6110")
3. Ladda upp en faktura med en rad som AI sannolikt inte kan kategorisera
4. Kontrollera att **No.** på raden blir "6110"

**Förväntat resultat:** Fallback till default-kontot fungerar

---

### Test 4: Inaktivera AI GL Suggestion

1. Gå till **AI Extraction Setup**
2. Avbocka **"Enable AI GL Suggestion"**
3. Ladda upp en ny faktura
4. Verifiera att alla rader får **Default G/L Account**

**Förväntat resultat:** När funktionen är avstängd används alltid default-kontot

---

### Test 5: Kontrollera JSON-struktur

För att verifiera att AI:n får rätt instruktioner, kan du temporärt lägga till debug-kod:

```al
// I QwenVLAPI.Codeunit.al, lägg till i BuildRequestJson:
Message('System Prompt: ' + SystemPrompt);
```

**Förväntat resultat:** System prompt ska innehålla:
- "ADDITIONAL INSTRUCTION FOR G/L ACCOUNT SUGGESTION"
- Lista över G/L-konton (t.ex. "- 6110: Office Supplies")

---

## Felsökning

### Problem: "No." är alltid tomt
**Lösning:** Kontrollera att:
- **Enable AI GL Suggestion** är aktiverat
- **Refresh Chart of Accounts** har körts
- Det finns G/L-konton med **Account Type** = "Posting" och **Blocked** = false

### Problem: AI föreslår felaktiga konton
**Lösning:**
- Kontrollera att kontobeskrivningarna i kontoplanen är tydliga
- Uppdatera kontoplanen med **Refresh Chart of Accounts**

### Problem: Förslag saknas trots matchande beskrivning
**Lösning:**
- Kontrollera att **Max Tokens** är tillräckligt högt (minst 2048)
- Om du har många G/L-konton (>100), överväg att begränsa vilka som skickas

---

## Exempel på fungerande flöde

```
Fakturarad: "Kontorsmaterial - Pennor och papper"
↓
AI analyserar mot kontoplan:
- 6110: Office Supplies
- 6120: IT Equipment
- 6130: Furniture
↓
AI föreslår: "6110" (baserat på "Kontorsmaterial")
↓
Import Document Line.No = "6110"
↓
Användaren kan redigera i Preview om det behövs
```

---

## Kontrollista

- [ ] Extension bygger utan fel
- [ ] Extension publiceras framgångsrikt
- [ ] Fältet "Enable AI GL Suggestion" visas i setup
- [ ] Action "Refresh Chart of Accounts" fungerar
- [ ] AI föreslår konton vid uppladdning
- [ ] Fallback till default-konto fungerar
- [ ] Inaktivering av funktionen fungerar
