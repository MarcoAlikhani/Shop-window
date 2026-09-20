# 🚀 FinPulse: The Story of Our Project

## 🍽️ Imagine a restaurant

Our project works **exactly like a restaurant**. Keep this picture in your head and everything becomes easy:

| 🍽️ Restaurant | 💻 FinPulse |
|---|---|
| 🚚 Farmers deliver ingredients | 🌐 Internet APIs send us money data |
| 📦 Storage room: boxes stored as they arrive | `fin_raw`: data saved exactly as received |
| 👨‍🍳 Kitchen: wash, cut, cook | ⚙️ Pipeline: clean + check the data |
| 🍝 Ready dishes, perfect quality | `fin_core`: clean, trusted data |
| 📋 Manager's logbook | `fin_ops`: "what ran, did it work?" |
| 🧾 Customer list + membership cards | `fin_app`: clients + API keys |
| 🤵 Waiter | 🔌 API: clients ask, API brings the answer |
| 🚫 Customers never walk into the kitchen | 🔒 Clients never touch the database directly |

That's the whole project. Seriously. Everything else is details 😎

---

## 💡 What FinPulse actually does

> **We collect money data from the internet, clean it, store it safely, and sell access to it.**

Think of apps that show *"1 EUR = 1.18 USD"* or a stock chart 📈. Somebody built the system **behind** that number. **That somebody is you.**

---

## 🧭 Follow one number through the system

Let's follow **"1 EUR = 1.18 USD"** on its journey:

```
🌐 Frankfurter API (European Central Bank data)
   │  "Hey, here are today's rates!"
   ▼
📦 fin_raw.api_response
   │  Saved as-is. Nobody touches it. It's our backup 🛟
   ▼
👨‍🍳 Pipeline cleans it
   │  "Is EUR a real currency? Is the rate positive? Any duplicates?"
   ▼
💎 fin_core.fx_rate
   │  2026-09-18 | EUR | USD | 1.18   ✅ clean + trusted
   ▼
🔌 API
   │  A client asks: "What's EUR→USD today?"
   ▼
📱 Client app shows: 1 EUR = 1.18 USD
```

And the whole time, 📋 `fin_ops` is writing in its diary: *"Run #57 started 16:05 ✅ finished, 30 rows loaded."*

---

## 🗄️ The 4 rooms of our database

| Room | Nickname | One-line job |
|---|---|---|
| `fin_raw` 📦 | **The Storage** | Keep everything exactly as it arrived |
| `fin_core` 💎 | **The Treasure** | Only clean, correct data lives here |
| `fin_ops` 📋 | **The Diary** | Remember every run and every quality check |
| `fin_app` 👥 | **The Front Desk** | Know who our customers are + what they use |

🧠 Quick reminder: a **schema** = a room. A **table** = a shelf inside the room. A **row** = one item on the shelf.

---

## 🛡️ Our database has bodyguards

We don't trust anyone, not even our own code 😏 So the database **protects itself**:

| Bodyguard 💪 | Stops this |
|---|---|
| **Primary key** 🔑 | The same rate saved twice |
| **Foreign key** 🔗 | Fake currencies like `XXX` |
| **CHECK** ✋ | Negative prices, high < low |
| **NOT NULL** 🚫 | Empty important values |
| **DECIMAL** 🎯 | Money rounding errors |

Bad data knocks on the door → **rejected** at the door. 🚪❌

---

## 🗝️ Everyone gets only the keys they need

| 🍽️ Restaurant | 👤 Database user | ✅ Can | ❌ Can't |
|---|---|---|---|
| 👨‍🍳 Cook | `finpulse_pipeline` | Store raw data, write clean data, log runs | Delete data, see customers |
| 🤵 Waiter | `finpulse_api` | Read clean data, check keys, log requests | Change data, see raw data |
| 🧐 Food critic | `finpulse_analyst` | Read clean data + run history | Change anything, see customers |

No more `root` (the master key 🔑) for daily work.

---

## 🗺️ Our journey (where are we?)

| # | Mission | Status |
|---|---|---|
| 1 | 🏛️ Design the database | ✅ Done |
| 2 | 🔐 Security: users + permissions | ✅ Done |
| 3 | 🐍 Pipeline: pull real data from the internet | 👉 **Next** |
| 4 | 🧹 Cleaning + quality checks | 🔜 |
| 5 | 🔌 Build the API (the waiter) | 🔜 |
| 6 | ☁️ Put it online for real clients | 🔜 |
| 7 | 📊 Monitoring, backups, speed | 🔜 |

By the end, this is a **real portfolio project** that looks like what data engineers build at actual companies 🏆

---

## 🎬 Next episode: "The first delivery truck" 🚚

We write the Python pipeline (managed with **uv** 🐍) that pulls **real** exchange rates from the internet into `fin_raw`, and logs every run in `fin_ops`.
