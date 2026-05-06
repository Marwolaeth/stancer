
<!-- README.md is generated from README.Rmd. Please edit that file -->

# stancer <img src="man/figures/logo.png" align="right" height="139" alt="" />

<!-- badges: start -->

[![R-CMD-check](https://github.com/Marwolaeth/stancer/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/Marwolaeth/stancer/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/Marwolaeth/stancer/graph/badge.svg)](https://app.codecov.io/gh/Marwolaeth/stancer)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

Stance Analysis using Ensemble of LLM Agents through `ellmer`

## Overview

**stancer** provides tools for automated stance analysis in R. It uses
an ensemble of Large Language Models (LLM) from user-provided `ellmer`
Wickham et al. ([2025](#ref-ellmer2025)) `Chat` objects to determine
whether a text is in favour of, against, or neutral towards a specific
target.

The package is built upon the **COLA** (Collaborative rOle-infused
LLM-based Agents) framework proposed by Lan et al.
([2024](#ref-lan2024stancedetectioncollaborativeroleinfused)). Instead
of a single prompt, `stancer` coordinates a team of LLM
agents—linguists, domain experts, and social media specialists—who
analyse the text and debate its meaning before reaching a final
judgement.

<div class="callout-note">

The COLA framework design (described below) requires several LLM API
calls. Specifically, it makes *seven separate calls for each document*
processed.

</div>

## Installation

You can install the development version of stancer from
[GitHub](https://github.com/) with:

``` r
# install.packages("pak")
pak::pak("Marwolaeth/stancer")
```

## Stance Analysis

In the era of “text-as-data”, researchers in media analytics and
sociology face the challenge of extracting structured meaning from vast
amounts of unstructured text. Traditional content analysis, as
established by Klaus Krippendorff
([2004](#ref-krippendorff2004content)), emphasizes that communication is
not just about frequencies but about inferences — how text relates to
its context and the intentions of its author. While practitioners often
aim for the “interpretive” depth described by Ahuvia
([2001](#ref-Ahuvia2001)), manual coding at scale is frequently
impossible.

A common pitfall in automated research is treating **Sentiment
Analysis** and **Stance Analysis** as interchangeable. However, as noted
by Bestvater and Monroe ([2023](#ref-BestvaterMonroe2023)), they are
conceptually distinct:

> Sentiment analysis techniques have a long history in natural language
> processing and have become a standard tool in the analysis of
> political texts, promising a conceptually straightforward automated
> method of extracting meaning from textual data by scoring documents on
> a scale from positive to negative. However, while these kinds of
> sentiment scores can capture the overall tone of a document, the
> underlying concept of interest for political analysis is often
> actually the document’s stance with respect to a given target—how
> positively or negatively it frames a specific idea, individual, or
> group—as this reflects the author’s underlying political attitudes.

In political discourse and social media monitoring, sentiment and stance
are often orthogonal and sometimes opposite. For example:

> “I am absolutely disgusted that the plastic ban proposal was
> rejected.”

**Sentiment:** Negative (the author is *disgusted*; also, for more
conservative methods, it may also matter that the *ban* proposal was
*rejected*).

**Stance (Target: Plastic Ban):** **Positive** (the author supports the
ban).

Standard sentiment lexicons would likely misclassify this as “Anti” due
to the negative tone. `stancer` addresses this by using the **COLA
framework** (Collaborative rOle-infused LLM-based Agents), which mimics
the deliberation of human coders to capture the “interpretive” nuances
of stance detection.

## How it works: The COLA Framework

Following the approach by Lan et al.
([2024](#ref-lan2024stancedetectioncollaborativeroleinfused)), `stancer`
breaks down stance detection into three distinct stages:

1.  **Multidimensional Analysis**: Three specialised agents (linguist,
    domain expert, and social media veteran) analyse the text’s meaning,
    style, terminology, and context.
2.  **Reasoning-Enhanced Debate**: For each possible stance polarity
    (Positive/Neutral/Negative), an agent is assigned to argue why the
    text might fit that category, based on analyses results from step 1.
    This helps uncover implicit viewpoints that a simple analysis might
    miss.
3.  **Stance Conclusion**: A final decision-maker agent reviews the
    analyses and the debate to provide a reasoned judgement and a final
    (structured) score.

## Supported Languages

`stancer` includes built-in, hand-crafted prompts for the following
languages:

- **English** (`"en"`)
- **Ukrainian** (`"uk"`)
- **Russian** (`"ru"`)

The package automatically detects the language of your text (using
`cld2` if available) or allows you to specify it manually in
`llm_stance()`. Currently, only the three languages listed above are
available.

## Usage

`stancer` works with chat objects from the
[ellmer](https://ellmer.tidyverse.org/) package. This gives you the
flexibility to use any supported model (OpenAI, Anthropic, Ollama, etc.)
as your analysis engine.

### Simple text analysis

``` r
library(stancer)
library(ellmer)

# Set up your LLM client
chat <- ellmer::chat_anthropic()

text <- "I am absolutely disgusted that the plastic ban proposal was rejected."
target <- "Plastic ban"

result <- llm_stance(
  text,
  target,
  type = "object", # stance towards a given object or entity 
  # type = "statement", # whether a text agrees with a certain statement
  chat_base = chat,
  domain_role = "economic analyst"
)

# View the summary
summary(result)
inspect(result, "analysis", "linguistic")
as.data.frame(result)
```

    #> # A tibble: 1 × 6
    #>   text                            target target_type language stance explanation
    #>   <chr>                           <chr>  <chr>       <chr>    <fct>  <chr>      
    #> 1 I am absolutely disgusted that… Plast… object      en       Posit… The explic…

Besides the traditional three-way scale (Negative/Neutral/Positive):
`scale = "categorical"`, two scale options are available:

- `likert` returns Likert scale ordinal factor response (Strongly
  Disagree … Strongly Agree)
- `numeric` returns numerical stance values. Warning: these values
  typically range from -1 to 1, but there is no guarantee of the value
  range. Therefore, `scale = "numeric"` is currently not recommended,
  especially for smaller models.

``` r
result_likert <- llm_stance(
    text,
    target,
    type = "object",
    chat_base = chat,
    domain_role = "social commentator",
    language = "en",
    scale = "likert"
)

as.data.frame(result_likert)[, c("target", "stance", "explanation")]
```

    #> # A tibble: 1 × 3
    #>   target      stance         explanation                                        
    #>   <chr>       <ord>          <chr>                                              
    #> 1 Plastic ban Strongly Agree The author expresses strong disgust at the rejecti…

The `inspect` method provides a deeper look at the analysis results,
including intermediate steps and detailed outputs generated during
processing. See `?inspect` for details and available arguments.

``` r
inspect(result_likert, "explanation")
```

    #> 
    #>  ── EXPLANATION: [row 1] ──────────────────────────────────────────────────────── 
    #> 
    #> The author expresses strong disgust at the rejection of the plastic
    ban proposal, indicating they view the ban as desirable. Explicit
    evaluation of the ban is absent, but the emotional tone (intensifier
    'absolutely' + 'disgusted') directed at the rejection signals a clear,
    intense positive stance toward the ban itself. Implicitly, the
    presupposition that the ban should have been accepted reinforces this
    support. Hence the majority of textual elements align with Strongly
    Agree.

### Data frame integration (mall-style)

Inspired by the `mall` package by Ruiz ([2026](#ref-mall2026)) from
[mlverse](https://github.com/mlverse), `stancer` provides a seamless way
to process entire datasets. It handles the row-wise operations and
returns a tidy data frame with the results.

``` r
library(stancer)
library(ellmer)
library(dplyr)

data("programming_tweets")

chat <- ellmer::chat_anthropic()

# Process the first three rows of the data frame
results <- programming_tweets |>
    dplyr::slice_head(n = 3) |>
    llm_stance(
        tweet,
        target = "Julia programming language",
        type = "object",
        chat = chat,
        domain_role = "computer scientis",
        language = "en",
        scale = "categorical"
    )

# The result is a tibble with a new .stance column
glimpse(results)
```

    #> Rows: 3
    #> Columns: 2
    #> $ tweet   <chr> "Julia's SciML ecosystem is absolutely phenomenal for solving complex differential equations. The performance and expressiveness combined i…
    #> $ .stance <fct> Positive, Positive, Positive

### Customizing Prompts

If you need to adapt the agents’ behaviour, support a new language, or
you find that the original prompts are too verbose and slow, you can
provide your own instructions. By using the `prompts_dir` argument, you
can point the package to a local folder containing custom `.md` files.

`stancer` will look for specific files (e.g., `user-linguist.md`,
`system-judger.md`, `description-likert.md`) in that directory. If a
file is missing, the package will gracefully fall back to its internal
defaults with respect to the `language` argument (`"en"` by default).
This allows you to override the system partially or entirely.

``` r
# Use custom instructions from a local folder
result <- llm_stance(
  text,
  target,
  type = "object",
  chat_base = chat,
  prompts_dir = "path/to/my_prompts/"
)
```

## Requirements

- R \>= 4.1.0
- [ellmer](https://ellmer.tidyverse.org/) for LLM integration.
- API access to your chosen LLM provider.

## Citation & Attribution

This implementation is based on the COLA framework from Lan et al.
([2024](#ref-lan2024stancedetectioncollaborativeroleinfused)).

When using this package, please cite the original COLA paper.

## References

<div id="refs" class="references csl-bib-body hanging-indent"
entry-spacing="0">

<div id="ref-Ahuvia2001" class="csl-entry">

Ahuvia, Aaron. 2001. “Traditional, Interpretive, and Reception Based
Content Analyses: Improving the Ability of Content Analysis to Address
Issues of Pragmatic and Theoretical Concern.” *Soc Indic Res* 54 (May).
<https://doi.org/10.1023/A:1011087813505>.

</div>

<div id="ref-BestvaterMonroe2023" class="csl-entry">

Bestvater, Samuel E., and Burt L. Monroe. 2023. “Sentiment Is Not
Stance: Target-Aware Opinion Classification for Political Text
Analysis.” *Political Analysis* 31 (2): 235–56.
<https://doi.org/10.1017/pan.2022.10>.

</div>

<div id="ref-krippendorff2004content" class="csl-entry">

Krippendorff, K. 2004. *Content Analysis: An Introduction to Its
Methodology*. Sage. <https://books.google.pl/books?id=jYdAAQAAIAAJ>.

</div>

<div id="ref-lan2024stancedetectioncollaborativeroleinfused"
class="csl-entry">

Lan, Xiaochong, Chen Gao, Depeng Jin, and Yong Li. 2024. “Stance
Detection with Collaborative Role-Infused LLM-Based Agents.”
<https://arxiv.org/abs/2310.10467>.

</div>

<div id="ref-mall2026" class="csl-entry">

Ruiz, Edgar. 2026. *Mall: Run Multiple Large Language Model Predictions
Against a Table, or Vectors*. <https://mlverse.github.io/mall/>.

</div>

<div id="ref-ellmer2025" class="csl-entry">

Wickham, Hadley, Joe Cheng, Aaron Jacobs, Garrick Aden-Buie, and Barret
Schloerke. 2025. *Ellmer: Chat with Large Language Models*.
<https://ellmer.tidyverse.org>.

</div>

</div>
