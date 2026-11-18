# Seeds for trying features

One file per feature, with the data to try it on staging. Each file finds its owner with
`User.find_by!(email_address: ENV.fetch("SEED_OWNER"))`, gives every record to that owner, uses dates
relative to today, and finds or creates each record, because staging runs the seeds on every build.

The other people of the business, such as a seller, are demo accounts: `User.demo_account!("seller", name: "Sam")`
makes `seller@demo.test` once, confirmed. `bin/rails atelier:people` lists them after the owner, labelled with
`atelier.people.seller` from the locale files, or with the name when that key is missing.
