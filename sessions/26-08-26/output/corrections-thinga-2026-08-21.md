# thinga — English lesson notes, 2026-08-21

Ten corrections from the 2026-08-21 lesson transcript (project talk + a JavaScript walkthrough for John), chosen for meaning, terminology and register.

### 1. `work around` means avoid, not improve
**You:** "the AI will review me and we can work around some weak spots that I will get"
**Better:** "the AI will review me and we can work on some weak spots that I will get"
`work around → work on`

> *Work around* a problem = find a way to bypass it. You told your teacher the plan is to route around your weak spots instead of practising them — the opposite of what you meant.

### 2. Variables are declared, not allocated
**You:** "it covers how we can allocate a variable in JavaScript there is a few ways of doing it"
**Better:** "it covers how we can declare a variable in JavaScript there is a few ways of doing it"
`allocate a variable → declare a variable`

> *Allocate* is about memory (`malloc`, allocating a buffer). In an interview, "allocate a variable" in a JS context sounds like you've confused the language model with manual memory management. Same fix later: "let's allocate a new variable" → "let's declare a new variable".

### 3. `verbally` vs `verbosely` — false friend
**You:** "but if we will write it more verbally it will look like this"
**Better:** "but if we will write it more verbosely it will look like this"
`verbally → verbosely`

> *Verbally* means out loud, in speech. You were contrasting `if (isActive)` with the longer `if (isActive === true)` — that's *verbosely*, or *more explicitly*.

### 4. Bracket names
**You:** "in the first one we use figured braces in this in this case we will use squared braces"
**Better:** "in the first one we use curly braces in this in this case we will use square brackets"
`figured braces → curly braces` · `squared braces → square brackets`

> These have fixed English names and every developer uses them: `{}` curly braces, `[]` square brackets, `()` parentheses (or round brackets). Later you said "in round bracers we have to write the condition" → "in parentheses we have to write the condition".

### 5. Passive: `is used`, not `uses`
**You:** "this one uses more frequently for some internal calculations of back-end responses"
**Better:** "this one is used more frequently for some internal calculations of back-end responses"
`uses → is used`

> As you said it, the object is the one doing the using. The listener has to stop and re-parse who acts on what — bad in an interview answer about how a structure is used.

### 6. `on the fly`
**You:** "it will run automatically on the flight we get the output straight after we press enter"
**Better:** "it will run automatically on the fly we get the output straight after we press enter"
`on the flight → on the fly`

> *On the fly* is the fixed idiom for "immediately, without a build step". "On the flight" isn't a phrase in English and lands as a mistake rather than a meaning.

### 7. `scripting language`, and `compile into`
**You:** "because JavaScript is a script based language it means that it runs in the environment you don't have to compile it in the program"
**Better:** "because JavaScript is a scripting language it means that it runs in the environment you don't have to compile it into a program"
`script based language → scripting language` · `compile it in the program → compile it into a program`

> *Scripting language* is the standard term — an interviewer expects it and "script based" sounds like you're guessing. *Compile it in the program* suggests compiling inside something; you meant turning it into an executable.

### 8. You don't visit a movie
**You:** "this year with my girlfriend we visited a lot of movies in cinema"
**Better:** "this year with my girlfriend we saw a lot of movies at the cinema"
`visited → saw` · `in cinema → at the cinema`

> *Visit* takes a place, not an event — you visit a city, you see a film. "Visited a lot of movies" is the kind of calque that immediately marks the sentence as translated.

### 9. `go off script`
**You:** "we also can go out of script easily it's just a template"
**Better:** "we also can go off script easily it's just a template"
`go out of script → go off script`

> *Go off script* is the set phrase for departing from a plan or agenda — useful and natural in meetings. "Go out of script" won't be misunderstood, but it's audibly not the phrase.

### 10. `agenda` is a meeting's topic list
**You:** "our agenda is very is very large 2200 pages this is insanely huge agenda"
**Better:** "our syllabus is very large 2200 pages this is insanely huge syllabus"
`agenda → syllabus`

> An *agenda* is the short list of items for one meeting, so "2200-page agenda" sounds absurd to a native listener. For a course document, use *syllabus*, *course outline*, or just *the course*.

## Left out

- Likely Whisper mishearings, not your errors: "death death tools" (dev tools), "a race" / "why is this a race" (array), "the 12th failure" and "represents its failure" (value), "a life sub sandbox" (live sandbox), "such a finish our exists", "which what is this gender suggesting" (agenda), "ID which will be sounds true" (string), "some more complicated videos" (values), "asking some chance" (questions), "syntax fiends", "in header server tables", "steppers ... $8" (slippers).
- Skipped grammar classes that recur but aren't worth list slots: articles (a/the/zero), *is/are* and plural agreement ("there is a few ways", "datas"), missing auxiliaries ("I focusing it English learning"), and *if + will* in conditions ("if we will write it", "if the condition will not pass" → "if we write it", "if the condition doesn't pass").
