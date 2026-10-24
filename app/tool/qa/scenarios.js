// QA scenarios for shoot.js. Each: { name, open: openApp options, run(page, helpers) }.
const onboarded = (themeId, extra = {}) => ({ themeId, onboarded: true, unit: 'metric', voiceId: 'classic', ...extra });

module.exports = [
  {
    name: 'home-palm-metro',
    open: { settings: onboarded('palm_metro') },
    run: async (page, { wait, shot }) => { await wait(9000); await shot(); },
  },
];
