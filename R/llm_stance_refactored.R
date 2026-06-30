# Refactored llm_stance with method parameter
# This shows the new dispatcher pattern

#' @param method Analysis framework: "cola" (default, collaborative agents),
#'   "pamr" (pragmatic-aware multi-agent reasoning), or "default" (simple baseline).
#'   See Details for comparison.

llm_stance.character <- function(
    x,
    target,
    chat_base,
    type = c('object'),
    language = stancer_available_languages(),
    scale = c('categorical', 'numeric', 'likert'),
    domain_role = NULL,
    prompts_dir = NULL,
    method = c("cola", "pamr", "default"),
    verbose = TRUE,
    rpm = 20,
    ...
) {
  ## Validation (common to all methods) ----
  tictoc::tic('Analysis')

  # Validate text and target
  text <- x
  validate_character(text)
  validate_character(target)

  n <- length(text)

  # Validate type
  if (rlang::is_character(type)) {
    if (length(type == 2) != n) {
      type <- rlang::arg_match(type, c('object', 'claim'), multiple = FALSE)
    } else {
      type <- rlang::arg_match(type, c('object', 'claim'), multiple = TRUE)
    }
  } else {
    cli::cli_abort(
      "{.arg type} must be a character vector, got {.cls {class(type)}}"
    )
  }

  # Validate language
  if (is.null(language) || length(language) > 1) {
    if (rlang::is_installed("cld2")) {
      language <- cld2::detect_language(text[[1]], lang_code = TRUE)
      cli::cli_warn(
        "The analysis language was automatically detected: {.val {language}}"
      )
    }
  }
  if (rlang::is_scalar_character(language)) {
    if (!language %in% stancer_available_languages()) {
      cli::cli_abort(
        c(
          "Language {.val {language}} not available",
          "i" = "Use one of: {.val {stancer_available_languages()}}"
        )
      )
    }
  } else {
    cli::cli_abort(
      "{.arg language} must be a character scalar, got \
             {.cls {class(language)}} of length {.val {length(language)}}"
    )
  }

  # Validate scale
  scale <- tolower(scale)
  scale <- rlang::arg_match(scale, c('categorical', 'numeric', 'likert'))

  # Validate method
  method <- rlang::arg_match(method)

  # Validate domain_role
  if (is.null(domain_role)) {
    domain_role <- switch(
      language,
      uk = 'sociologist',
      ru = 'sociologist',
      'social commentator'
    )
  } else {
    if (!rlang::is_character(domain_role) || length(domain_role) < 1) {
      cli::cli_abort(
        "{.arg domain_role} must be a character vector, got {.cls {class(domain_role)}}"
      )
    }
    if (!(length(domain_role) == 1 || length(domain_role) == n)) {
      cli::cli_abort(
        c(
          "{.arg domain_role} must have length 1 or {n} (same as {.arg text})",
          "x" = "Got {length(domain_role)}"
        )
      )
    }
  }

  if (length(domain_role) > 1) {
    cli::cli_warn(
      "Multiple domain roles detected. Parallel execution is unsupported."
    )
  }

  ### Chat Validation ----
  chats <- if (rlang::is_list(chat_base)) {
    for (i in seq_along(chat_base)) {
      if (!ellmer:::is_chat(chat_base[[i]])) {
        cli::cli_abort(
          "Element {i} of {.arg chat_base} is not an {.cls ellmer::Chat} object"
        )
      }
    }

    indices <- switch(
      length(chat_base),
      `1` = c(1, 1, 1),
      `2` = c(1, 1, 2),
      `3` = c(1, 2, 3),
      cli::cli_abort(
        c(
          "{.arg chat_base} must have 1, 2, or 3 elements",
          "x" = "You provided {length(chat_base)}"
        )
      )
    )
    lapply(indices, \(i) chat_base[[i]]$clone(deep = TRUE))

  } else if (ellmer:::is_chat(chat_base)) {
    rep(list(chat_base$clone(deep = TRUE)), times = 3)

  } else {
    cli::cli_abort(
      c(
        "{.arg chat_base} must be an {.cls ellmer::Chat} object or \
                a list of 1-3 {.cls ellmer::Chat} objects",
        "x" = "Got {.cls {class(chat_base)}}"
      )
    )
  }

  ## Prompts ----
  prompt_templates <- templates_collect(prompts_dir, language, scale)

  ## Preparation ----
  target <- recycle_arg(target, n)
  type <- recycle_arg(type, n)

  target_types <- sapply(type, type_to_term, language = language)

  inputs <- list(
    texts = text,
    targets = target,
    types = type,
    target_types = target_types,
    language = language,
    scale = scale,
    domain_roles = domain_role,
    prompt_templates = prompt_templates
  )

  if (verbose) {
    cat("\n")
    cat(strrep("=", 70), "\n")
    cat(glue::glue("\U1F50D STANCE ANALYSIS ({toupper(method)}) - Processing {n} item(s)"), "\n")
    cat(strrep("=", 70), "\n\n")
    cat(glue::glue("Method: {toupper(method)}"), "\n")
    cat(glue::glue("Types: {paste(unique(type), collapse = ', ')}"), "\n")
    cat(glue::glue("Language: {language}"), "\n")
    cat(
      glue::glue("Domain roles: {paste(unique(domain_role), collapse = ', ')}"),
      "\n"
    )
    cat("\n")
  }

  ## Dispatcher by method ----
  output <- switch(
    method,
    "cola" = analyze_with_cola(inputs, chats, verbose, rpm, ...),
    "pamr" = analyze_with_pamr(inputs, chats, verbose, rpm, ...),
    "default" = analyze_with_default(inputs, chats, verbose, rpm, ...)
  )

  if (is.null(output$judgement_results) || nrow(output$judgement_results) != n) {
    cli::cli_abort("Final stance judgement returned unexpected results")
  }

  ## Postprocessing ----
  # Additional postprocessing of quantitative and Likert stance labels
  if (scale == 'numeric') {
    # output$judgement_results$stance <- truncate(
    #     (output$judgement_results$stance - 50) / 50,
    #     -1,
    #     1
    # )
  } else if (scale == 'likert') {
    scale <- 'Likert'
    output$judgement_results$stance <- factor(
      output$judgement_results$stance,
      levels = c(
        'Strongly Disagree',
        'Disagree',
        'Neutral',
        'Agree',
        'Strongly Agree'
      ),
      ordered = TRUE
    )
  } else if (scale == "categorical") {
    output$judgement_results$stance <- factor(
      as.character(output$judgement_results$stance),
      levels = c('Negative', 'Neutral', 'Positive'),
      ordered = FALSE
    )
  }

  ## Summary ----
  summary_df <- data.frame(
    text = text,
    target = target,
    target_type = type,
    language = language
  ) |>
    cbind(output$judgement_results) |>
    tibble::as_tibble()

  if (verbose) {
    cat("\U1F4CA Summary Table:\n")
    print(summary_df)
    cat("\n")
    cat(strrep("=", 70), "\n")
    toc <- tictoc::toc(func.toc = stage_complete, quiet = FALSE)
    cat(strrep("=", 70), "\n\n")
  } else {
    toc <- tictoc::toc(func.toc = stage_complete, quiet = TRUE)
  }

  ## Return ----
  structure(
    list(
      summary = summary_df,
      analysis = output$analysis_results,
      debates = output$debate_results,
      judgements = output$judgement_results,
      metadata = list(
        n_total = n,
        n_processed = nrow(output$judgement_results),
        n_failed = sum(is.na(output$judgement_results$stance)),
        scale = scale,
        language = language,
        types = unique(type),
        domain_role = domain_role,
        method = method,
        model = unique(sapply(chats, \(chat) chat$get_model())),
        elapsed = toc$toc - toc$tic,
        timestamp = Sys.time()
      )
    ),
    class = c("stance_result", "list")
  )
}
