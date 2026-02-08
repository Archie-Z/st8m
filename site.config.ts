import siteConfig from "./src/utils/config";

const config = siteConfig({
	title: "ST8-M",
	prologue: "What I cannot create, I do not understand. \n — Richard P. Feynman.",
	author: {
		name: "Archie",
		email: "archie.z@zohomail.cn",
		link: "https://st8m.cc"
	},
	description: "Personal blog of Archie, a lazy developer.",
	copyright: {
		type: "CC BY-NC-ND 4.0",
		year: "2026"
	},
	i18n: {
		locales: ["en", "zh-cn", "ja"],
		defaultLocale: "en"
	},
	pagination: {
		note: 15,
		jotting: 24
	},
	heatmap: {
		unit: "day",
		weeks: 20
	},
	feed: {
		section: "*",
		limit: 20
	},
	latest: "*"
});

export const monolocale = Number(config.i18n.locales.length) === 1;

export default config;
