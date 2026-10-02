export const STATUS = {
  open: { label: 'Open', color: 'var(--blue)', bg: 'var(--blueBg)', bd: 'var(--blueBd)' },
  assigned: { label: 'Assigned', color: 'var(--accent)', bg: 'var(--accentBg)', bd: 'var(--accentBd)' },
  in_progress: { label: 'In Progress', color: 'var(--orange)', bg: 'var(--orangeBg)', bd: 'var(--orangeBd)' },
  resolved: { label: 'Resolved', color: 'var(--green)', bg: 'var(--greenBg)', bd: 'var(--greenBd)' },
  rejected: { label: 'Rejected', color: 'var(--red)', bg: 'var(--redBg)', bd: 'var(--redBd)' },
};

export const PRIORITY = {
  urgent: { label: 'Urgent', color: 'var(--red)', bg: 'var(--redBg)', bd: 'var(--redBd)' },
  high: { label: 'High', color: 'var(--orange)', bg: 'var(--orangeBg)', bd: 'var(--orangeBd)' },
  normal: { label: 'Normal', color: 'var(--green)', bg: 'var(--greenBg)', bd: 'var(--greenBd)' },
};

export const DEPTS = [
  'Road Department', 'Electric Department', 'Sanitation Department',
  'Water Supply', 'Traffic Control', 'Tree Authority', 'General Administration',
];

export const STEPS = [
  { key: 'Reported', label: 'Complaint Registered' },
  { key: 'Forwarded', label: 'Forwarded to Department' },
  { key: 'Assigned', label: 'Acknowledge & Assigned' },
  { key: 'In Progress', label: 'Work in Progress' },
  { key: 'Resolved', label: 'Complaint Resolved' },
  { key: 'Rejected', label: 'Request Rejected' },
];
export const ESCALATION_HOURS = 48; // Hours before a complaint is considered 'stale'

export const CAT_COLORS = [
  'var(--accent)', 'var(--blue)', 'var(--green)',
  'var(--purple)', 'var(--teal)', 'var(--yellow)',
  'var(--red)', 'var(--pink)',
];

export const CATEGORY_DEPARTMENT_MAP = {
  // Road Department
  'Road Damage': 'Road Department',
  'cat_road': 'Road Department',
  'pothole': 'Road Department',
  'road_damage': 'Road Department',
  'crack': 'Road Department',
  'Pothole': 'Road Department',

  // Electric Department
  'Streetlight': 'Electric Department',
  'cat_light': 'Electric Department',
  'broken_streetlight': 'Electric Department',
  'streetlight': 'Electric Department',
  'light': 'Electric Department',
  'Broken Streetlight': 'Electric Department',

  // Sanitation Department
  'Garbage & Waste': 'Sanitation Department',
  'Garbage': 'Sanitation Department',
  'cat_garbage': 'Sanitation Department',
  'garbage_dump': 'Sanitation Department',
  'overflowing_bin': 'Sanitation Department',
  'garbage': 'Sanitation Department',
  'waste': 'Sanitation Department',
  'Garbage Dump': 'Sanitation Department',
  'Overflowing Bin': 'Sanitation Department',

  // Water Supply
  'Water Supply': 'Water Supply',
  'cat_water': 'Water Supply',
  'drainage_issue': 'Water Supply',
  'water_leak': 'Water Supply',
  'Drainage Issue': 'Water Supply',

  // Traffic Control
  'Traffic & Signals': 'Traffic Control',
  'Traffic Control': 'Traffic Control',
  'cat_traffic': 'Traffic Control',
  'traffic_signal': 'Traffic Control',
  'traffic': 'Traffic Control',

  // Tree Authority
  'Fallen Trees / Branches': 'Tree Authority',
  'cat_tree': 'Tree Authority',
  'fallen_tree': 'Tree Authority',
  'tree': 'Tree Authority',
  'Fallen Tree': 'Tree Authority',

  // General Administration / Other
  'Encroachment': 'General Administration',
  'cat_encroach': 'General Administration',
  'encroachment': 'General Administration',
  'cat_other': 'General Administration',
  'Other Issue': 'General Administration',
  'Other': 'General Administration',
};

export const getDepartmentForCategory = (categoryOrLabel) => {
  if (!categoryOrLabel) return 'General Administration';
  const clean = categoryOrLabel.trim();
  if (CATEGORY_DEPARTMENT_MAP[clean]) return CATEGORY_DEPARTMENT_MAP[clean];
  const lower = clean.toLowerCase().replace(/\s+/g, '_');
  if (CATEGORY_DEPARTMENT_MAP[lower]) return CATEGORY_DEPARTMENT_MAP[lower];
  for (const [key, dept] of Object.entries(CATEGORY_DEPARTMENT_MAP)) {
    if (clean.toLowerCase().includes(key.toLowerCase()) || key.toLowerCase().includes(clean.toLowerCase())) {
      return dept;
    }
  }
  return 'General Administration';
};
