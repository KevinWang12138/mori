import { localize } from './i18n'

export function editFields(title: string, fields: { label: string; value: string; multiline?: boolean }[],
  onSave: (values: string[]) => void): void {
  document.querySelector('dialog')?.remove()
  const dialog = document.createElement('dialog'); dialog.className = 'editor-dialog'
  const heading = document.createElement('h3'); localize(heading, { text: title }); dialog.append(heading)
  const inputs = fields.map(field => {
    const label = document.createElement('label'); const caption = document.createElement('span'); localize(caption, { text: field.label }); label.append(caption)
    const input = document.createElement(field.multiline ? 'textarea' : 'input')
    input.value = field.value; input.spellcheck = false
    label.append(input); dialog.append(label); return input
  })
  const footer = document.createElement('footer')
  const cancel = document.createElement('button'); localize(cancel, { text: '取消' }); cancel.onclick = () => dialog.close()
  const save = document.createElement('button'); localize(save, { text: '完成' }); save.className = 'primary'
  save.onclick = () => { onSave(inputs.map(input => input.value)); dialog.close() }
  footer.append(cancel, save); dialog.append(footer)
  dialog.addEventListener('close', () => dialog.remove()); document.body.append(dialog); dialog.showModal(); inputs[0]?.focus()
}
