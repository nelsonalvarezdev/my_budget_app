# BudgetApp — rules and architecture

Part 1 is the rulebook: what the app does. Part 2 is how the code is organised.
The rules in Part 1 are pinned by unit tests in `Tests/`; if a test and this document disagree, one of them is wrong.

---

## Part 1 — The rules

### 1.1 Overview

iOS 18+, SwiftUI + SwiftData, Swift 6 (strict concurrency), no third-party dependencies. Currency is Colombian pesos, whole amounts, shown as `$ 1.500.000`.

Three pages live side by side in a custom horizontal pager (`RootView`), all alive at once. You move between them with the bottom tab bar, or by swiping on the tab bar or on the strip over the navigation title. List rows keep their own gestures.

| Tab | View | Model | In this document |
|---|---|---|---|
| Transactions | `TransactionsView` | `Transaction` | **Transaction** — day-to-day log; each one moves real money |
| Monthly | `MonthlyView` | `FixedExpense` | **Monthly item** — a fixed expense or fixed income |
| Expenses ("More expenses") | `ExpensesView` | `NonFixedExpense`, `SubExpense` | **Extra entry** — adjusts the Balance |

> Naming: the stored model classes keep their original names (`FixedExpense`, `NonFixedExpense`) because renaming a SwiftData model changes the database schema. New code, comments and this document use the vocabulary above.

### 1.2 Stored state

**SwiftData models**

- `Transaction` — `name`, `amount` (always > 0), `kind` (income/expense), `category` (plain text, not a link), `note`, `date`, `paidWith` (cash / savings / creditCard).
- `FixedExpense` — `name`, `amount` (> 0), `isChecked`, `isIncome`, `category` (optional link to `ExpenseCategory`).
- `NonFixedExpense` — `name`, `amount`, `isIncome`, plus two special modes: `isCumulative` (+ `subExpenses`) and `isRecurring` (+ `baseAmount`, `multiplier`).
- `SubExpense` — `value` only.
- `ExpenseCategory` — `name`, `colorHex`.

**Settings** (`AccountsStore`, persisted in `UserDefaults` as plain-digit strings)

- `cashBalance`, `savingsBalance` — the two account fields on Transactions.
- `monthlyIncome` — the income field on Monthly.

### 1.3 The big picture: three money circuits

```
 Transactions ──create──▶ Cash / Savings fields ─┐
                                                 ├─▶ Balance = Cash + Savings − Σ extra expenses + Σ extra incomes
 Expenses view (extra entries) ──────────────────┘

 Monthly view ──▶ Monthly expenses (checked net) ──▶ Remaining = Monthly income − checked net
        ▲
        └── a Transaction created from a Monthly item checks that item (the only bridge)
```

1. **Real money** — Cash and Savings. Edited by hand, and moved once when a transaction is created.
2. **Balance adjustments** — extra entries never touch Cash/Savings; they are subtracted from (expenses) or added to (incomes) the Balance.
3. **Monthly plan** — self-contained. It only produces "Monthly expenses" and "Remaining"; it never touches Cash, Savings or Balance.

### 1.4 Transactions view

**Balance card (pinned)**

- **Balance** = `Cash + Savings − Σ extra expenses + Σ extra incomes`. It is **global by design**: the same figure whatever month is displayed. Red when negative.
- **Cash** and **Savings** are two editable tiles inside the card; the value is committed when editing ends (blur or Enter).
- **Available to spend** = Cash + Savings, shown under the tiles.

**List**

- **Income / Spent** = sums of the displayed month's transactions. Informational only; they do not feed the Balance.
- Each day's header shows the day's net (income − expenses). Each row has a dot in its category's colour.
- New transactions are added with the floating + button.

**List**

- Filtered to the displayed month (‹ › to change month, tap the title for today), grouped by day, newest first.

**Creating a transaction**

- Requires a non-empty name and an amount > 0.
- An expense may be created from a Monthly item ("Fixed expense" picker, which lists every Monthly item, incomes included). Picking one prefills name, amount and category, all still editable. On save that item becomes **checked** in Monthly, even if the amount was edited.
- Category options: for expenses, `None` + the shared category list; for incomes, a fixed list (Salary, Freelance, Gift, Investment, Other). Switching type resets the category.
- Effect on the account fields, applied once at save time:

| Kind | Paid with | Effect |
|---|---|---|
| Expense | Cash | Cash − amount |
| Expense | Savings account | Savings − amount |
| Expense | Credit card | none (deferred payment) |
| Income | — | Cash + amount |

**Deleting**

- Swipe to delete, or **Delete all transactions** (⋯ menu, with confirmation).
- **By design, deleting removes the record, not the money movement**: Cash/Savings are not reverted, the Balance does not change, and a Monthly item it checked stays checked.
- Transactions cannot be edited.

**Monthly report** (⋯ menu)

- For the displayed month: total income, total expenses, net, and totals per category (largest first). Downloadable as CSV.

**Backup** (⋯ menu) — see 1.7.

### 1.5 Monthly view

- **Monthly income** — manually entered, in the headline card ("of $ …").
- Items are fixed **expenses** or fixed **incomes**. The type is chosen when adding and cannot be changed afterwards.
- **Monthly expenses** = `Σ checked expenses − Σ checked incomes`.
- **Remaining** = `Monthly income − Monthly expenses`. The card's headline; red when negative.
- The **bar** shows Monthly expenses as a share of the income (solid) and, behind it, the estimated share once every item is checked (lighter). Both are clamped to 0–100 %.
- **Hold** the Remaining amount or the "Paid" label to peek at the *estimate*, which counts every item regardless of checked state:
  - Estimated monthly expenses = `Σ all expenses − Σ all incomes`
  - Estimated monthly remains = `Monthly income − that`
- **Tapping a row toggles its check** ("paid / received this month"). Editing and deleting are in the swipe actions and the long-press menu.
- **Uncheck all** resets every item — the manual start-of-month reset. Nothing resets automatically. It is enabled whenever at least one item is checked.
- Expenses can have a category: rows are grouped by category, uncategorized last, tinted with the category colour (uncategorized rows turn green when checked). Incomes have no category and are always green.
- Amounts must be > 0.
- Checking or unchecking has **no effect** on Cash, Savings or Balance.

**Categories**

- Eight built-in defaults (Housing, Food & Groceries, Transport, Utilities, Health, Entertainment, Education, Savings). They cannot be deleted and are re-created at launch if missing.
- Users can add their own (name + colour) and delete them. Monthly items lose the link; transactions keep the category name as text.

### 1.6 Expenses view ("More expenses")

The headline card shows the **Effect on balance** = `Σ incomes − Σ expenses` of this view. Below it are two sections: **Expenses**, then **Incomes** (shown only when there are incomes). Within each, special entries come first. Each header shows the section total.

Three kinds of entry, chosen at creation (None / Cumulative / Recurring). Only a name is required.

| Kind | Amount rule | Editing |
|---|---|---|
| Plain | Whatever is typed. May be negative: a negative expense acts as a credit. | Name and amount edited in place; trash button |
| Cumulative (tag: "n values") | `amount = Σ sub-values`. Optional initial sub-value at creation. | Tap opens the sub-value list: add, edit, delete (non-zero values) |
| Recurring (tag: "base × n") | `amount = base amount × multiplier`. Multiplier starts at 1, minimum 1. | + button adds one; "Remove one" is in the leading swipe and the long-press menu; tap opens a modal to edit the base |

- Expense vs income is fixed at creation; special incomes behave exactly like special expenses.
- Every change immediately moves the Balance (expenses subtract, incomes add). Cash and Savings are untouched.
- Deleting an entry also deletes its sub-values.

### 1.7 Cross-cutting rules

- **Backup** — Export writes one JSON file with every model plus the three settings. Import **replaces everything** after a confirmation. Optional DTO fields keep old backups importable. **Any new model or field must be added to the backup.**
- **SwiftData migrations** — every new `@Model` property needs a default value, or lightweight migration silently fails.
- **Amounts** — stored positive with the sign implied by kind/`isIncome`, except plain extra entries, which may be negative. All typed amounts are parsed by `Currency.parseAmount`.
- **Currency fields** show formatted pesos when idle and raw digits while focused; tapping outside dismisses the keyboard.
- **No mock data** — a fresh install starts empty (only the default categories are created).

### 1.8 Decisions log

| # | Question | Decision (2026-11-16) |
|---|---|---|
| 1 | Deleting a transaction does not return the money | Intentional — rule in 1.4 |
| 2 | Balance is the same for every displayed month | Intentional — rule in 1.4 |
| 3 | Mock data re-seeded whenever a list was empty | Removed — the app never inserts mock data |
| 4 | "Fixed expense" picker also lists fixed incomes | Keep; variables renamed to `monthlyItems` |
| 5 | Balance read extra entries with a manual fetch | Now a `@Query` (no behaviour change) |
| 6 | Sub-values left orphaned in the store on delete | Fixed — deletes now remove them |
| 7 | Monthly row tap: toggle or edit? | Tap toggles the check |
| 8 | Decimal amounts | Whole pesos only; one shared parser |
| 9 | "NFE" naming clash | Model names kept; vocabulary clarified (1.1) |

---

## Part 2 — Architecture

### 2.1 Shape

Light MVVM. The rules live in one plain-Swift layer; views do layout; view models hold screen state and user intents.

```
Views (SwiftUI)          layout, @Query, bindings, navigation
   │  pass data in, call intents
ViewModels (@Observable) screen state + intents, only where a screen has real logic
   │  delegate every calculation
Domain (plain Swift)     the rules from Part 1 — no SwiftUI
   │
Data                     SwiftData models · AccountsStore (UserDefaults) · BackupService
```

**`@Query` stays in the views.** It only works inside a view, and it is what makes lists refresh automatically. Views hand the query results to their view model or to a Domain function. A view model never fetches.

### 2.2 Layout

```
Sources/
  App/            BudgetAppApp (container + AccountsStore), RootView (pager, tab bar, launch seeding)
  Models/         Transaction, FixedExpense, NonFixedExpense (+ SubExpense), ExpenseCategory
  Domain/         TransactionRules, BalanceRules, MonthlyTotals,
                  NonFixedExpense+Rules, ExtraEntrySections, Currency
  Data/           AccountsStore, BackupService, BackupFile
  Features/
    Transactions/ TransactionsView + ViewModel, AddTransactionView + ViewModel,
                  MonthlyReportView, TransactionRow, BalanceHeroCard
    Monthly/      MonthlyView + ViewModel, AddEditFixedExpenseView, CategoryManagerView
    Expenses/     ExpensesView + ViewModel, AddMoreExpenseView, SubExpensesView
  Shared/         Theme (accent colour, HeroCard, SectionHeader, CategoryDot, TagPill),
                  CurrencyField, DismissKeyboardOnTap, ColorHelpers
Tests/            unit tests for Domain, AccountsStore and the view models
```

`Sources/` and `Tests/` are folder-synchronised in the Xcode project: a new file in either folder is picked up automatically.

### 2.3 Where each rule lives

| Rule | Code |
|---|---|
| Transaction → Cash/Savings effect | `TransactionRules.accountEffect` |
| Month filter, day groups, totals, category totals | `TransactionRules` |
| Balance, Available to spend | `BalanceRules` |
| Monthly expenses, Remaining, estimates | `MonthlyTotals` |
| Cumulative / Recurring amounts, entry deletion | `NonFixedExpense+Rules` |
| Creating an extra entry, the Expenses sections | `ExtraEntrySections.swift` |
| Formatting and parsing amounts | `Currency` |
| Cash, Savings, Monthly income storage | `AccountsStore` |
| Saving a transaction (insert + effect + check) | `AddTransactionViewModel.save` |

### 2.4 Conventions

- A new formula goes in `Domain/` with a test, never in a view.
- One accent colour (`Color.brand`, the icon's green) for money in and things done; red for money out. Each tab opens with a `HeroCard`; totals go in section headers, not footers.
- Only `AccountsStore` reads or writes the three settings keys.
- A screen gets a view model when it has state or logic worth testing. Small forms and reusable rows (`AddEditFixedExpenseView`, `CategoryManagerView`, `CurrencyField`, `BalanceHeroCard`) stay plain views.
- View models are `@MainActor @Observable`, owned by their view with `@State`, and receive `ModelContext` / `AccountsStore` as method arguments.
- Deliberately not used: repository protocols, use-case classes, a DI container, coordinators, TCA, extra modules. Revisit only if the app gains sync, multiple accounts or a second platform.

### 2.5 Running the tests

```bash
xcodebuild -project BudgetApp.xcodeproj -scheme BudgetApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

`project.yml` mirrors the test target, but the checked-in `.xcodeproj` is the source of truth (XcodeGen is not installed on this machine).

### 2.6 Known leftovers

- Sub-values orphaned by earlier versions are still in existing stores. They are invisible and ignored by totals and backups; an export + import clears them.
