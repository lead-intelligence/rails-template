# Seeds for trying features

One file per feature, with the data to try it on staging. Each file finds its owner with
`User.find_by!(email_address: ENV.fetch("SEED_OWNER"))`, gives every record to that owner, uses dates
relative to today, and finds or creates each record, because staging runs the seeds on every build.
