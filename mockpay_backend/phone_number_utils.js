function normalizePhone(value) {
  if (typeof value !== 'string' || !/^[+0-9\s()\-]*$/.test(value.trim())) return null;
  let number = value.trim().replace(/[\s()\-]/g, '');
  let international = false;
  if (number.startsWith('+')) {
    if (!number.startsWith('+60')) return null;
    number = number.slice(3);
    international = true;
  } else if (number.startsWith('00')) {
    if (!number.startsWith('0060')) return null;
    number = number.slice(4);
    international = true;
  } else if (number.startsWith('60') && number.length >= 10) {
    number = number.slice(2);
    international = true;
  }
  if (international && number.startsWith('0')) return null;
  if (!international && number.startsWith('0')) number = number.slice(1);
  if (!/^(?:1[0-9]{8,9}|3[0-9]{8}|[4-9][0-9]{7})$/.test(number)) return null;
  return '+60' + number;
}
module.exports = { normalizePhone };
