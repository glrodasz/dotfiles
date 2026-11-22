# Plain English

Apply these rules to every piece of text that great-readme writes: the README, the `docs/`
files, alt text, tables, commit messages and the PR description. Write plain English that a
smart reader outside the field understands on one read. The rules come from ASD-STE100, the
controlled language that aerospace uses for maintenance manuals.

Adapted from [Simple English](https://github.com/AminBlg/SimpleEnglish) by AminBlg
(MIT License, see the end of this file).

## Rules

1. Classify each passage. Procedural text tells the reader what to do: imperative mood, 20 words per sentence, one instruction per sentence. Descriptive text explains: simple tenses, 25 words per sentence, one topic per paragraph, six sentences per paragraph at most.
2. Never touch code, identifiers, commands, flags, file paths, quoted errors, product names, or facts. When the source gives no number or cause, keep the general statement.
3. Condition before command, with a comma: "If the build fails, read the log."
4. Use simple tenses and active voice. No present perfect ("has completed" → "completed"). No "-ing" verb after a comma (", making it easy" → new sentence). Name the actor: "You run the migration."
5. Modals: can, will, must. Never should, would, may, might, could. A required "should" becomes "must". An optional one is deleted.
6. Use complete grammar. No contractions, keep articles, keep "that". Write short sentences, not telegraph style.
7. No semicolons and no em-dashes. Write two sentences, or name the relation.
8. One word, one meaning, for the whole document. Use `make sure that` for check, verify, confirm, validate, ensure. Use `configuration` for config, settings, options. Break noun chains over three words with a preposition ("the timeout value for the connection pool").
9. Give the reader each term and each fact before the step that needs it. Define a concept term at its first use, under ten words, one per sentence. Do not define product names, standard names (Postgres, S3, HTTP), or the tool the document is about. Also name the host, the flag, or the prior step that a command depends on. "Restart the service" becomes "Restart the `sync` service on the host that runs the job."
10. State the fact, not its importance. Delete words that carry no fact: simply, seamlessly, robust, powerful, comprehensive, leverage, crucial, "in order to", "it is worth noting". No "not just X, it is Y". No decorative triplets. No "in conclusion".
11. Use formatting only where it carries structure. No bold lead-ins, no bold as emphasis, no emoji, no heading over two sentences. A vertical list is for three or more parallel items or steps: colon on the lead-in, uppercase start, one instruction per item.
12. Warnings: command or condition first, then the risk. "Do not run this against production. The command deletes rows."

Use American spelling. Commit messages and PR descriptions: imperative subject line,
descriptive body, 25 words per sentence in the body. Delete "this PR aims to".

Before (AI output):

> **Connection timeouts.** If sqlpipe hangs or fails with `dial tcp: i/o timeout`, check that the host running sqlpipe can reach the Postgres port (usually 5432) — this is often a security group or firewall rule blocking the connection. If you're connecting to a managed database (RDS, Cloud SQL, etc.), confirm the instance allows connections from sqlpipe's IP.

After (procedural, headed, numbered):

> ## Connection timeouts
>
> sqlpipe stops with `dial tcp: i/o timeout` when it cannot connect to the Postgres port (5432 by default).
>
> 1. Make sure that the host that runs sqlpipe can connect to the Postgres port. A firewall or security group usually blocks it.
> 2. If the database is managed (RDS, Cloud SQL), make sure that the instance accepts connections from the IP of sqlpipe.

## Self-check

Run this on each file before you deliver it:

1. Count the words in your three longest sentences. Over 20 (procedural) or 25 (descriptive), split.
2. Search for `'`, `has been`, `should`, `may`, `;`, `—`, `, making`, `**`, `check`, `verify`, `config`, and any heading that covers fewer than three sentences. Fix each hit.
3. Read each step. If it does not name the host, the flag, or the prior step that the reader must already have, add it or point to it.

## Word swaps

If the word carries no fact, delete it instead of replacing it.

| Slop | Write instead |
|---|---|
| leverage, utilize | use |
| in order to | to |
| prior to | before |
| ensure | make sure that |
| it is worth noting that | (delete) |
| it's important to | (delete, then state the fact) |
| simply, just, easily, seamless, seamlessly, effortlessly | (delete) |
| robust, powerful, comprehensive, performant | (delete, or give the measurable property) |
| functionality | function, feature |
| enables you to, allows you to | you can |
| is designed to, aims to | (delete, then say what it does) |
| facilitate | help, make possible |
| dive into, delve into | read, examine |
| when it comes to | for |
| in the event that | if |
| due to the fact that | because |
| as needed, as necessary | (state the condition) |
| and/or | Pick one, or write "X, or Y, or both" |
| e.g. / i.e. / etc. | for example / that is / (name the items) |
| gracefully handles | (say what it does: "retries three times, then stops") |
| out of the box | by default |
| under the hood | internally |
| blazingly fast | fast (give the number) / (delete) |
| streamline | make simpler, make faster |
| plethora, myriad | many |
| addresses the issue, tackles | corrects the fault, removes the error |
| pivotal, crucial, crucially, paramount | important |
| tapestry, testament, synergy | (delete) |
| interplay | interaction (or delete) |
| intricate | complex |
| vibrant, nuanced, multifaceted | (delete, or name the parts) |
| realm, landscape (metaphorical) | area |
| groundbreaking, cutting-edge, state-of-the-art, innovative, unprecedented | new (or delete) |
| transformative, game-changer | (delete, then say what changes) |
| revolutionize | change |
| showcase, underscore, emphasize | show |
| foster, empower, bolster | help, support, let |
| harness | use |
| enhance | improve |
| elevate | increase |
| furthermore, moreover | also |
| in conclusion, in summary, at the end of the day | (delete) |
| embark, endeavor | start, try |
| meticulous, meticulously | careful, carefully |
| holistic | full |
| paradigm | model |
| navigate (metaphorical) | go to |
| boasts | has |
| nestled, in the heart of | (delete, then give the location or the fact) |
| bustling | busy |
| that being said, notwithstanding | but |
| I hope this helps, let's dive in | (delete) |

## License

The rules, the example, the self-check and the word swaps above come from Simple English.

MIT License

Copyright (c) 2026 AminBlg

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
