const Stripe = require("stripe");
const stripe = Stripe(
  "sk_test_51SxaMyAntToJSaE8RmIUChGLs1Ub3j0wCuCHfaZhziU2rZSbMYU9ve7XcUbHvnFuoyl5ulCHM4fbM04Vg2359U3M00hZMAs2ZA",
);

async function listLinks() {
  try {
    const links = await stripe.paymentLinks.list({
      limit: 20,
    });

    links.data.forEach((link) => {
      console.log(`ID: ${link.id}`);
      console.log(`  - URL: ${link.url}`);
    });
  } catch (e) {
    console.error(e);
  }
}

listLinks();
