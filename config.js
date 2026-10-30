// 1) Supabase > Project Settings > API: paste the Project URL and the PUBLIC key (anon / publishable).
//    The public key is safe to commit to GitHub; your data is protected by the rules in setup.sql.
//    NEVER paste the secret / service_role key here.
// 2) Leave url and key empty to preview the site with sample data.
window.CFG = {
  url: "https://taoukekwxdnrlunbheww.supabase.co",
  key: "sb_publishable_hgtq6LDKBp7uk8EMLyGcDg_zYWHhShd",
  name: "you",
  // Edit these strings to personalize the opening letter.
  letter: {
    recipient: "MR. S. D. SETYAWAN",
    addressLines: [
      "The Cupboard Under the Stairs",
      "4 Privet Drive",
      "Little Whinging",
      "Surrey"
    ],
    salutation: "Dear Satrio,",
    paragraphs: [
      "We are pleased to inform you that you have been given a chance to explore this web page. A small collection of moments and thoughtful details has been gathered especially for you.",
      "You are invited to wander through the pages at your own pace. A letter, a song, a few memories, and other little keepsakes are waiting to be discovered along the way.",
      "There is no need to hurry, and no special equipment is required. A little curiosity will be quite enough; simply follow the links and let each page reveal what it has been keeping.",
      "We very much hope your visit brings a smile, a fond memory, and a touch of magic to an otherwise ordinary day."
    ],
    closing: "Yours sincerely,",
    signature: "Professor McGonagall"
  }
};
