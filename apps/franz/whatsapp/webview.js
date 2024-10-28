"use strict";

const path = require('path');

setTimeout(() => {
  const elem = document.querySelector('.landing-title.version-title');

  if (elem && elem.innerText.toLowerCase().includes('google chrome')) {
    window.FranzAPI.clearCache();
    window.location.reload();
  }
}, 1000);

const isMutedIcon = element => element.parentElement.parentElement.querySelectorAll('*[data-icon="muted"]').length !== 0;

const isPinnedIcon = (element) => element.querySelectorAll('*[data-icon="pinned2"]').length !== 0;

module.exports = Franz => {
  const getMessages = function getMessages() {
    const elements = document.querySelectorAll('.CxUIE, .unread, ._ak7n, ._0LqQ, .m61XR .ZKn2B, .VOr2j, ._1V5O7 ._2vfYK, html[dir] ._23LrM, ._1pJ9J:not(._2XH9R), ._2H6nH, [data-testid="icon-unread-count"]');
    let count = 0;

    for (let i = 0; i < elements.length; i += 1) {
      try {
        if (!isMutedIcon(elements[i]) && !isPinnedIcon(elements[i])) {
          count += 1;
        }
      } catch (err) {}
    }

    Franz.setBadge(count);
  };

  Franz.injectCSS(path.join(__dirname, 'service.css'));
  Franz.loop(getMessages);
};