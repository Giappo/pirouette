#' Creates a posterior from the phylogeny
#' @param phylogeny a phylogeny
#' @param sequence_length the number of basepairs the simulated DNA
#'   alignment consists of
#' @param mutation_rate the mutation rate per base pair per time unit
#' @param mcmc MCMC options, as created by \link[beautier]{create_mcmc}
#' @param crown_age the fixed crown age of the posterior. Set to NA
#'   to let it be estimated
#' @param mrca_distr if MRCA prior used on all taxa.
#'   Set to NA to not use an MRCA prior
#' @param site_models one or more nucleotide substitution models,
#'   as created by \link[beautier]{create_site_model}
#' @param clock_models one or more clock models,
#'   as created by \link[beautier]{create_clock_model}
#' @param tree_priors one or more tree priors,
#'   as created by \link[beautier]{create_tree_prior}
#' @param alignment_rng_seed The random number generator seed used
#'   to generate an alignment
#' @param beast2_rng_seed The random number generator seed used by BEAST2
#' @param verbose if TRUE, show more output
#' @param beast_jar_path Where the jar 'beast.jar' can be found
#' @return a posterior of phylogenies
#' @export
#' @author Richel J.C. Bilderbeek
pir_run <- function(
  phylogeny,
  sequence_length,
  mutation_rate,
  mcmc,
  site_models = beautier::create_jc69_site_model(),
  clock_models = beautier::create_strict_clock_model(),
  tree_priors = beautier::create_bd_tree_prior(),
  crown_age = NA,
  mrca_distr = NA,
  alignment_rng_seed = 0,
  beast2_rng_seed = 1,
  verbose = FALSE,
  beast_jar_path = beastier::get_default_beast2_jar_path()
) {
  if (!is.na(beast2_rng_seed) && !(beast2_rng_seed > 0)) {
    stop("'beast2_rng_seed' should be NA or non-zero positive")
  }
  # Create alignment
  set.seed(alignment_rng_seed)
  alignment <- sim_alignment(
    phylogeny = phylogeny,
    sequence_length = sequence_length,
    mutation_rate = mutation_rate
  )
  # Save alignment to file
  temp_fasta_filename <- tempfile(pattern = "pirouette_", fileext = ".fasta")
  phangorn::write.phyDat(
    alignment,
    file = temp_fasta_filename,
    format = "fasta"
  )

  mrca_prior <- NA
  if (beautier:::is_distr(mrca_distr)) {
    mrca_prior <- beautier::create_mrca_prior(
      alignment_id = beautier::get_alignment_id(temp_fasta_filename),
      taxa_names = beautier::get_taxa_names(temp_fasta_filename),
      is_monophyletic = TRUE,
      mrca_distr = mrca_distr
    )
  }

  babette_out <- babette::bbt_run(
    fasta_filenames = temp_fasta_filename,
    site_models = site_models,
    clock_models = clock_models,
    tree_priors = tree_priors,
    mrca_priors = mrca_prior,
    mcmc = mcmc,
    posterior_crown_age = crown_age,
    rng_seed = beast2_rng_seed,
    cleanup = TRUE,
    verbose = verbose
  )

  file.remove(temp_fasta_filename)

  list(
    alignment = alignment,
    # Use c() to convert to multiPhylo. This removes the STATE_x names
    trees = c(babette_out[[grep(x = names(babette_out), pattern = "trees")]]),
    estimates = babette_out$estimates
  )
}
