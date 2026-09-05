#!/usr/bin/env node

const { spawn } = require('child_process');

const SETTINGS = {
  active_text_color: '#eeeeee',
  active_bg: '',
  active_underline: '#FEEF69',
  inactive_text_color: '#888888',
  inactive_bg: '',
  inactive_underline: '',
  separator: '·',
  forbidden_classes: 'Polybar Conky Gmrun',
  empty_desktop_message: 'Desktop',
  char_limit: 35,
  max_windows: 15,
  char_case: 'normal',
  add_spaces: 'true',
};

let on_click_prefix = '';

const herb = (args) => {
  return new Promise((resolve, reject) => {
    const proc = spawn('herbstclient', args);
    let stdout = '';
    let stderr = '';
    proc.stdout.on('data', (data) => stdout += data);
    proc.stderr.on('data', (data) => stderr += data);
    proc.on('close', (code) => {
      if (code === 0) resolve(stdout.trim());
      else reject(new Error(stderr.trim() || `herbstclient failed with code ${code}`));
    });
  });
};

const herbAttr = (path) => {
  return herb(['attr', path]).catch(() => '');
};

const getActiveWid = async () => {
  return herbAttr('clients.focus.winid');
};

const listClients = async () => {
  const currentTag = await herbAttr('tags.focus.name');
  if (!currentTag) return [];

  const output = await herb(['list_clients', `--tag=${currentTag}`]);
  const clients = [];

  output.split('\n').forEach(line => {
    const wid = line.trim();
    if (!wid) return;

    clients.push({
      wid,
    });
  });

  return clients;
};

const getWindowList = async () => {
  const clients = await listClients();
  const windowList = [];

  for (const client of clients) {
    const cls = await herbAttr(`clients.${client.wid}.class`);
    const min = await herbAttr(`clients.${client.wid}.minimized`);
    const ttl = await herbAttr(`clients.${client.wid}.title`);
    windowList.push({
      wid: client.wid,
      class: cls,
      minimized: min === 'true',
      title: ttl,
    });
  }

  return windowList;
};

const scrollFocus = async (dir) => {
  const clients = await getWindowList();
  const activeWid = await getActiveWid();

  const wids = clients.map(c => c.wid);
  const activePos = wids.indexOf(activeWid);
  let newPos;

  if (dir === 'up') {
    newPos = activePos <= 0 ? wids.length - 1 : activePos - 1;
  } else {
    newPos = activePos >= wids.length - 1 ? 0 : activePos + 1;
  }

  const target = wids[newPos];
  if (target) {
    await herb(['jumpto', target]);
  }
};

const raiseOrMinimize = async (wid) => {
  await herb(['lock']);

  try {
    const isMinimized = await herbAttr(`clients.${wid}.minimized`);
    const isFloating = await herbAttr(`clients.${wid}.floating`);
    const activeWid = await getActiveWid();

    if (isMinimized === 'true') {
      await herb(['jumpto', wid]);
      const curframeCount = await herbAttr('tags.focus.curframe_wcount');
      if (parseInt(curframeCount) < 1) {
        await herb(['attr', `clients.${wid}.floating`, 'false']);
      }
    } else if (isFloating === 'true') {
      await herb(['attr', `clients.${wid}.floating`, 'false']);
    } else if (wid === activeWid) {
      await herb(['set_attr', `clients.${wid}.floating`, 'true']);
      await herb(['set_attr', `clients.${wid}.minimized`, 'true']);
    } else {
      await herb(['jumpto', wid]);
      await herb(['raise', wid]);
    }
  } finally {
    await herb(['unlock']);
  }
};

const closeWindow = async (wid) => {
  await herb(['close', wid]);
};

const windowOps = async (wid) => {
  const title = await herbAttr(`clients.${wid}.title`);
  return new Promise((resolve) => {
    const proc = spawn('rofi', [
      '-dmenu',
      '-l', '4',
      '-theme', '~/.config/rofi/window-ops.rasi',
      '-p', title || 'window'
    ]);

    proc.stdin.write('Close\nFocus\nMinimize\nToggle floating\n');
    proc.stdin.end();

    proc.stdout.on('data', (data) => {
      const choice = data.toString().trim();
      if (choice === 'Close') {
        closeWindow(wid);
      } else if (choice === 'Focus') {
        herb(['attr', `clients.${wid}.pseudotile`, 'toggle']);
      } else if (choice === 'Minimize') {
        herb(['attr', `clients.${wid}.minimized`, 'toggle']);
      } else if (choice === 'Toggle floating') {
        herb(['attr', `clients.${wid}.floating`, 'toggle']);
      }
      resolve();
    });

    proc.on('close', () => resolve());
  });
};

const generateWindowList = async () => {
  const activeWid = await getActiveWid();
  let windowCount = 0;

  const windowList = await getWindowList();

  const classGroups = new Map();
  windowList.forEach(win => {
    const cls = win.class;
    if (!classGroups.has(cls)) {
      classGroups.set(cls, {
        wid: win.wid,
        title: win.title,
        isActive: win.wid === activeWid,
        count: 0,
      });
    }
    const group = classGroups.get(cls);
    group.count++;
    if (win.wid === activeWid) {
      group.isActive = true;
      group.wid = win.wid;
      group.title = win.title;
    }
  });

  const formatWindowName = (name) => {
    if (SETTINGS.char_case === 'lower') {
      name = name.toLowerCase();
    } else if (SETTINGS.char_case === 'upper') {
      name = name.toUpperCase();
    }
    return name;
  };

  const truncateName = (name) => {
    if (name.length > SETTINGS.char_limit) {
      return name.substring(0, SETTINGS.char_limit - 1) + '…';
    }
    return name;
  };

  let activeL = `%{F${SETTINGS.active_text_color}}`;
  let activeR = '%{F-}';
  let inactiveL = `%{F${SETTINGS.inactive_text_color}}`;
  let inactiveR = '%{F-}';

  if (SETTINGS.active_underline) {
    activeL = `${activeL}%{+u}%{u${SETTINGS.active_underline}}`;
    activeR = `%{-u}${activeR}`;
  }

  if (SETTINGS.active_bg) {
    activeL = `${activeL}%{B${SETTINGS.active_bg}}`;
    activeR = `%{B-}${activeR}`;
  }

  if (SETTINGS.inactive_underline) {
    inactiveL = `${inactiveL}%{+u}%{u${SETTINGS.inactive_underline}}`;
    inactiveR = `%{-u}${inactiveR}`;
  }

  if (SETTINGS.inactive_bg) {
    inactiveL = `${inactiveL}%{B${SETTINGS.inactive_bg}}`;
    inactiveR = `%{B-}${inactiveR}`;
  }

  const output = [];
  let first = true;

  for (const [cls, group] of classGroups) {
    if (SETTINGS.forbidden_classes.includes(cls)) {
      continue;
    }

    if (windowCount >= SETTINGS.max_windows) {
      windowCount++;
      continue;
    }

    let wName = group.title || cls;
    wName = formatWindowName(wName);
    wName = truncateName(wName);

    if (SETTINGS.add_spaces === 'true') {
      wName = ` ${wName} `;
    }

    const leftFmt = group.isActive ? activeL : inactiveL;
    const rightFmt = group.isActive ? activeR : inactiveR;

    let entry = '';
    if (!first) {
      entry += `%{F${SETTINGS.inactive_text_color}}${SETTINGS.separator}%{F-}`;
    }
    first = false;

    const clickActions = [];
    clickActions.push(`%{A1:${on_click_prefix} raise_or_minimize ${group.wid}:}`);
    clickActions.push(`%{A2:${on_click_prefix} close ${group.wid}:}`);
    clickActions.push(`%{A3:${on_click_prefix} window_ops ${group.wid}:}`);
    clickActions.push(`%{A4:${on_click_prefix} scroll_focus up:}`);
    clickActions.push(`%{A5:${on_click_prefix} scroll_focus down:}`);

    entry += clickActions.join('');
    entry += `${leftFmt}${wName}${rightFmt}`;
    entry += '%{A}%{A}%{A}%{A}%{A}';

    output.push(entry);
    windowCount++;
  }

  let result = output.join('');

  if (windowCount > SETTINGS.max_windows) {
    result += `+${windowCount - SETTINGS.max_windows}`;
  }

  if (windowCount === 0) {
    result = SETTINGS.empty_desktop_message;
  }

  result += '\n';
  process.stdout.write(result);
};

const generateWindowListByFrame = async () => {
  const activeWid = await getActiveWid();
  let windowCount = 0;

  const windowList = await getWindowList();

  const windowWithFrames = [];
  for (const win of windowList) {
    const frameIdx = await herbAttr(`clients.${win.wid}.parent_frame.index`);
    windowWithFrames.push({
      ...win,
      frameIndex: frameIdx ? parseInt(frameIdx) : 0,
    });
  }

  windowWithFrames.sort((a, b) => (a.frameIndex || 0) - (b.frameIndex || 0));

  const classGroups = new Map();
  windowWithFrames.forEach(win => {
    const cls = win.class;
    const key = `${win.frameIndex || 0}-${cls}`;
    if (!classGroups.has(key)) {
      classGroups.set(key, {
        frameIndex: win.frameIndex || 0,
        wid: win.wid,
        title: win.title,
        isActive: win.wid === activeWid,
        count: 0,
        cls,
      });
    }
    const group = classGroups.get(key);
    group.count++;
    if (win.wid === activeWid) {
      group.isActive = true;
      group.wid = win.wid;
      group.title = win.title;
    }
  });

  const groups = Array.from(classGroups.values()).sort((a, b) => {
    if (a.frameIndex !== b.frameIndex) {
      return a.frameIndex - b.frameIndex;
    }
    return a.cls.localeCompare(b.cls);
  });

  let activeL = `%{F${SETTINGS.active_text_color}}`;
  let activeR = '%{F-}';
  let inactiveL = `%{F${SETTINGS.inactive_text_color}}`;
  let inactiveR = '%{F-}';

  if (SETTINGS.active_underline) {
    activeL = `${activeL}%{+u}%{u${SETTINGS.active_underline}}`;
    activeR = `%{-u}${activeR}`;
  }

  if (SETTINGS.active_bg) {
    activeL = `${activeL}%{B${SETTINGS.active_bg}}`;
    activeR = `%{B-}${activeR}`;
  }

  if (SETTINGS.inactive_underline) {
    inactiveL = `${inactiveL}%{+u}%{u${SETTINGS.inactive_underline}}`;
    inactiveR = `%{-u}${inactiveR}`;
  }

  if (SETTINGS.inactive_bg) {
    inactiveL = `${inactiveL}%{B${SETTINGS.inactive_bg}}`;
    inactiveR = `%{B-}${inactiveR}`;
  }

  const output = [];
  let first = true;

  for (const group of groups) {
    if (SETTINGS.forbidden_classes.includes(group.cls)) {
      continue;
    }

    if (windowCount >= SETTINGS.max_windows) {
      windowCount++;
      continue;
    }

    let wName = group.title || group.cls;

    if (SETTINGS.char_case === 'lower') {
      wName = wName.toLowerCase();
    } else if (SETTINGS.char_case === 'upper') {
      wName = wName.toUpperCase();
    }

    if (wName.length > SETTINGS.char_limit) {
      wName = wName.substring(0, SETTINGS.char_limit - 1) + '…';
    }

    if (SETTINGS.add_spaces === 'true') {
      wName = ` ${wName} `;
    }

    const leftFmt = group.isActive ? activeL : inactiveL;
    const rightFmt = group.isActive ? activeR : inactiveR;

    let entry = '';
    if (!first) {
      entry += `%{F${SETTINGS.inactive_text_color}}${SETTINGS.separator}%{F-}`;
    }
    first = false;

    const clickActions = [];
    clickActions.push(`%{A1:${on_click_prefix} raise_or_minimize ${group.wid}:}`);
    clickActions.push(`%{A2:${on_click_prefix} close ${group.wid}:}`);
    clickActions.push(`%{A3:${on_click_prefix} window_ops ${group.wid}:}`);
    clickActions.push(`%{A4:${on_click_prefix} scroll_focus up:}`);
    clickActions.push(`%{A5:${on_click_prefix} scroll_focus down:}`);

    entry += clickActions.join('');
    entry += `${leftFmt}${wName}${rightFmt}`;
    entry += '%{A}%{A}%{A}%{A}%{A}';

    output.push(entry);
    windowCount++;
  }

  let result = output.join('');

  if (windowCount > SETTINGS.max_windows) {
    result += `+${windowCount - SETTINGS.max_windows}`;
  }

  if (windowCount === 0) {
    result = SETTINGS.empty_desktop_message;
  }

  result += '\n';
  process.stdout.write(result);
};

const run = async () => {
  on_click_prefix = 'polywins.js';

  const action = process.argv[2];

  switch (action) {
    case 'generate':
    case 'generate-frame':
      if (action === 'generate-frame') {
        await generateWindowListByFrame();
      } else {
        await generateWindowList();
      }
      break;
    case 'raise_or_minimize':
      await raiseOrMinimize(process.argv[3]);
      break;
    case 'close':
      await closeWindow(process.argv[3]);
      break;
    case 'scroll_focus':
      await scrollFocus(process.argv[3]);
      break;
    case 'window_ops':
      await windowOps(process.argv[3]);
      break;
    case 'switcher':
      spawn('rofi', [
        '-modi', 'windowcd',
        '-show', 'windowcd',
        '-theme', '~/.config/rofi/window-switcher.rasi',
        '-window-match-fields', 'class',
        '-filter', process.argv[3] || ''
      ], { stdio: 'inherit' });
      break;
    default:
      console.error(`Unknown action: ${action}`);
      process.exit(1);
  }
};

run().catch(err => {
  console.error(err);
  process.exit(1);
});